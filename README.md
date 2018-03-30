# TCGA_mRNA_expression_preprocess
This R script is used to fetch TCGA mRNA expression data from BigQuery, and then filtered/preprocessed for developing TCGA cancer gene prediction model. 

## Prerequisite
- [R 3.0+](https://www.r-project.org)
- [data.table](https://github.com/Rdatatable/data.table): install.packages('data.table')
- [dplyr](https://github.com/tidyverse/dplyr): install.packages('dplyr')
- [tidyr](http://tidyr.tidyverse.org): install.packages('tidyr)
- [bigrquery](https://github.com/r-dbi/bigrquery): devtools::install_github("rstats-db/bigrquery")
- [argparser](https://github.com/trevorld/argparse): devtools::install_github("argparse", "trevorld")
- [google cloud account](https://cloud.google.com/) 


## Run
```
		Rscript tcga_mRNA_preprocessing.R -o <output directory>

		for example: Rscript tcga_mRNA_preprocessing.R -o ~/Desktop 
```

## outputs 
- {TCGA project name}_mRNA.csv.gz 
