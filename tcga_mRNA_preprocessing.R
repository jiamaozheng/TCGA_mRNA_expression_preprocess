# Author: Jiamao Zheng (jiamaoz@yahoo.com) 03/30/2018 

# install.packages("bigrquery")
# install.packages('devtools')
# devtools::install_github("rstats-db/bigrquery")

library(data.table)
library(dplyr)
library(tidyr)
library(bigrquery)
library(argparser)

p <- arg_parser("Run TCGA mRNA expression preprocessing")
p <- add_argument(p, "--output_path", short="-o", help="Output directory", default=".")
argv <- parse_args(p)

# google cloud project ID 
project <- "cancer-predictdb" 
cat('google cloud project ID: ', project, '\n\n')

# TCGA projects 
cat('querying all TCGA project names from BigQuery RNAseq data \n')
# https://bigquery.cloud.google.com/table/isb-cgc:TCGA_hg19_data_v0.RNAseq_Gene_Expression_UNC_RSEM
all_projects_sql <- "SELECT UNIQUE(project_short_name) FROM [isb-cgc:TCGA_hg19_data_v0.RNAseq_Gene_Expression_UNC_RSEM]"
all_projects = query_exec(all_projects_sql, project = project, use_legacy_sql = T)
colnames(all_projects) = c('project_name')
cat('TCGA has ', nrow(all_projects), ' projects \n')
cat('done.\n\n')

# gene_symbols from genecode_v19
# https://bigquery.cloud.google.com/table/isb-cgc:genome_reference.GENCODE_v19
cat('querying gene symbols from BigQuery genecode v19')
gene_symbols_sql <- "SELECT unique(gene_name) FROM [isb-cgc:genome_reference.GENCODE_v19] WHERE gene_type ='protein_coding' AND seq_name NOT IN ('chrX')"
gene_symbols <- query_exec(gene_symbols_sql, project = project, use_legacy_sql = T)
colnames(gene_symbols) <- 'gene_symbol'
cat('Genecode v19 has ', nrow(gene_symbols), ' gene symbols \n')
cat('done. \n\n')

# mRNA 
for(project_name in all_projects) {
        cat('querying expression from BigQuery RNAseq data based on ', project_name, '\n')
        mRNA_sql <- paste("
         SELECT 
                aliquot_barcode,
                HGNC_gene_symbol AS gene_symbol,
                normalized_count AS expression
         FROM 
                [isb-cgc:TCGA_hg19_data_v0.RNAseq_Gene_Expression_UNC_RSEM]
         WHERE 
                project_short_name = '", project_name, "'", "AND
                 platform IN ('IlluminaHiSeq', 'IlluminaGA') AND  
                HGNC_gene_symbol IS NOT NULL", sep='')

        mRNA <- query_exec(mRNA_sql, project = project, useLegacySql = T, max_pages = Inf, destination_table = 'cancer-predictdb:temp.mRNA', create_disposition = "CREATE_IF_NEEDED",
                           write_disposition = "WRITE_TRUNCATE") 
        
        # Genes were selected based on expression thresholds of >0.1 RPKM in >=10 samples (filter 20182 - 19641 genes for BRCA, 20182 - 19422). GTEx standard.
        cat('Genes were selected based on expression thresholds of >0.1 RPKM in >=10 samples \n')
        filtered_gene_list <- mRNA %>% select(-aliquot_barcode) %>% group_by(gene_symbol) %>% summarise(count=sum(expression > 0.1)) %>% filter(count > 10)

        cat('subset data based on genecode v19 gene symbols \n')
        # for BRCA: 1215 x 17322 for OV: 309 X 17139 
        mRNA <- mRNA %>% spread(gene_symbol, expression) %>% select(aliquot_barcode, one_of(intersect(gene_symbols$gene_symbol, filtered_gene_list$gene_symbol)))

        output_dir <- paste(output_path, project_name, sep = '')
        if (!dir.exists(output_dir)){
                dir.create(output_dir)
        } else {
                cat(output_dir, " Dir already exists!\n")
        }

        cat('writing data into disk \n')
        write.csv(mRNA, file = gzfile(paste(output_dir, '/', project_name, '_mRNA', '.csv.gz', sep = '')),  quote = FALSE, row.names = F)
        cat('done!')
}
