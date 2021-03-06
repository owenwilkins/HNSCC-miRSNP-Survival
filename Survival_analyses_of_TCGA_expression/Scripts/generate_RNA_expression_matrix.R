###########################
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Read in miRNAseq data from TCGA HNSCC cases and generate expression matrix
# Authors: Owen Wilkins 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
###########################
rm(list = ls())
setwd("/Users/Owen 1//Thesis/HNSCC_miRSNP/")

#------------------------------------------------------------------------------------------
# read in data
#------------------------------------------------------------------------------------------

# read in covaraite file 
covs <- readRDS("05_TCGA_expression_survival_analyses/Data_files/TCGA_HNSC_covariates_miRNA_expression_subset.rds")
covs$bcr_patient_uuid <- tolower(covs$bcr_patient_uuid)

# load in metadata 
metadata <- read.table("05_TCGA_expression_survival_analyses/Data_files/TCGA_HNSC_metadata_2017-04-07T22-01-38.673662.txt", sep = "\t", header = T, stringsAsFactors = F)

# RNA_seq data
setwd("/Users/Owen 1//Thesis/HNSCC_miRSNP/05_TCGA_expression_survival_analyses/RNA-seq/")
dir("/Users/Owen 1//Thesis/HNSCC_miRSNP/05_TCGA_expression_survival_analyses/RNA-seq/")

#------------------------------------------------------------------------------------------
# read in and process RNA-seq data for analysis 
#------------------------------------------------------------------------------------------

# get all file name in directory 
filelist = list.files(path = dir(),pattern = ".txt", full.names = TRUE)
filelist

# note: there are "annotation.txt" files associated with 36 subjects that indicate if case was found to be a recurrence
# after submission, if the patient had a simulatneous cancer of another kind etc. 
# these cases should be removed 
indicies_to_drop <- grep("annotations.txt", filelist)
filelist_2 <- filelist[-indicies_to_drop]

# read in all files 
datalist = lapply(filelist_2, function(x) read.table(x, header=F, stringsAsFactors = F)) 

# split the IDs from filelist_2 and match them to the metadata 
get_ids <- function(vector_to_split) strsplit(vector_to_split, "/")[[1]][2]
filelist_3 <- sapply(filelist_2, get_ids)
names(datalist) <- filelist_3
names(datalist)[1:5]
names(filelist_3) <- NULL

# check that all filelist items are in metadata 
table(filelist_3 %in% metadata$file_name)
# 2 is missing as filelist has 502 eklements and metadata data has 500

filelist_4 <- filelist_3[match(metadata$file_name, filelist_3)] # index filelist for subjects w/ metadata 
filelist_5 <- filelist_4[order(filelist_4)] # order metadata and filelist the same way  
metadata_2 <- metadata[order(metadata$file_name),]
all(metadata_2$file_name == filelist_5) # check they are identical 

datalist_2 <- datalist[match(filelist_5, names(datalist))] # index datalist for elements w/ matching IDs in filelist_5
datalist_3 <- datalist_2[order(names(datalist_2))] # order datalist_2 same way as filelist_5
all(filelist_5 == names(datalist_3)) # check they are identical 

names(datalist_3)[1:5]
filelist_5[1:5]
metadata_2$file_name[1:5]

names(datalist_3) <- metadata_2$cases.case_id # give datalist patient_uuid as names (instead of file uuid)
datalist_4 <- datalist_3[order(names(datalist_3))] # order based on this new variable 

#------------------------------------------------------------------------------------------
# add patient UUID to RNA_seq data (to link expression and clinical data)
#------------------------------------------------------------------------------------------

# check to see if all subjects in covs are in the datalist 
table(tolower(covs$bcr_patient_uuid) %in% names(datalist_4))
# there are 5 missing, so remove those 5 when you index covariates for subjects with metadata 

# index covs for those in metadata 
covs_2 <- covs[na.omit(match(names(datalist_4), tolower(covs$bcr_patient_uuid))),] 
# index datalist for subjects in covariate data so they match 
datalist_5 <- datalist_4[na.omit(match(tolower(covs_2$bcr_patient_uuid), (names(datalist_4))))]
# order covariate data and datalist in same way 
covs_3 <- covs_2[order(tolower(covs_2$bcr_patient_uuid)),] 
datalist_6 <- datalist_5[order(names(datalist_5))]
# check datalist and covs_2 are in same order with same identifiers 
all(tolower(covs_3$bcr_patient_uuid) == names(datalist_6)) 

# make matrix to hold expression data 
expression <- matrix(NA, nrow = length(covs_3$bcr_patient_uuid), ncol = length(datalist_4[[1]]$V1)) 
colnames(expression) <- datalist_4[[1]]$V1
rownames(expression) <- covs_2$bcr_patient_uuid
for(i in 1:length(datalist_6)){
  expression[i,] <- datalist_6[[i]]$V2
} # fill matrix w/ expression data 
expression[1:10, 1:5]

# clean up workspace
rm(filelist_5, filelist_4, filelist_3, filelist_2, filelist, covs_2, covs, metadata, metadata_2, 
   datalist, datalist_2, datalist_3, datalist_4, indicies_to_drop)

#------------------------------------------------------------------------------------------
# subset subjects by expression of genes of interest + run Kaplan Meier analysis 
#------------------------------------------------------------------------------------------

# check indicies in expression matrix for genes of interest to see if present
which(colnames(expression) == "ENSG00000130147.14") # SH3BP4 # BOG25 # TPP # EHB10
which(colnames(expression) == "ENSG00000259571.1") # BLID

# save expression matrix for RNA-seq data 
setwd("/Users/Owen 1/Thesis/HNSCC_miRSNP/")
saveRDS(expression, file = "05_TCGA_expression_survival_analyses/Data_files/TCGA_HNSCC_tumor_RNAseq_expression_matrix.rds")

rm(datalist_5, datalist_6, i, x, y, get_ids)

#------------------------------------------------------------------------------------------
# clean and pre-process covariate data from subset of subjects w/ RNA-seq data in the same way 
# as done for subjects with miRNAseq data in 'generate_miRNA_expression_matrix.R'
#------------------------------------------------------------------------------------------
covs <- covs_3
rm(covs_3)

# confirm subject order still matches 
all(covs$bcr_patient_uuid == rownames(expression))

# add expression data to covs 
covs$sh3bp4_continuous <- log2(expression[,which(colnames(expression) == "ENSG00000130147.14")])
covs$blid_continuous <- log2(expression[,which(colnames(expression) == "ENSG00000259571.1")])

# combine death and follow uop variable to get time to event for alive and dead subjects 
covs$time_to_event <- NA
covs$time_to_event[is.na(covs$days_to_death)] <- covs$days_to_last_followup[is.na(covs$days_to_death)]
covs$time_to_event[!is.na(covs$days_to_death)] <- covs$days_to_death[!is.na(covs$days_to_death)]
covs$time_to_event

# consider age, sex, race and tumor stage variables 
covs$age_at_initial_pathologic_diagnosis
covs$gender
covs$gender <- factor(covs$gender, levels = c("MALE", "FEMALE"))
covs$race_list

# process race variable to 'white' 'non-white' 
covs$race_list[covs$race_list == "BLACK OR AFRICAN AMERICAN"] <- "NON-WHITE"
covs$race_list[covs$race_list == "ASIAN"] <- "NON-WHITE"
covs$race_list[covs$race_list == "BLACK OR AFRICAN AMERICAN"] <- "NON-WHITE"
covs$race_list[covs$race_list == ""] <- NA
covs$race_list

# remove those with NAs for race + re-level 
covs$race_list <- factor(covs$race_list, levels = c("WHITE", "NON-WHITE"))
covs_2 <- covs[!is.na(covs$race_list),]

# split complicated stage variable up and extract stage number data 
x <- strsplit(covs_2$stage_event, " ")
stages <- c()
for(i in 1:length(x)){
  stages[i] <- x[[i]][2]
}
stages
table(stages)

# write function to assign each complicated stage character string to stage I, II, III or IV 
tumor_stage <- c()
for(i in 1:length(stages)){
  # if element 2 of character string is I, then if element 3 is I this is stage 3, if else is stage II
  if(strsplit(stages, "")[[i]][2] == "I")
    if(strsplit(stages, "")[[i]][3] == "I"){
      tumor_stage[i] <- "IIIStage"
    } else {tumor_stage[i] <- "IIStage"}
  # if element 2 is V, then stage is 4 
  else if(strsplit(stages, "")[[i]][2] == "V"){
    tumor_stage[i] <- "IVStage"
  } else {tumor_stage[i] <- "IStage"}
}
tumor_stage
table(tumor_stage)

# parse to more clear levels 
tumor_stage[tumor_stage == "IStage"] <- "I+II"
tumor_stage[tumor_stage == "IIStage"] <- "I+II"
tumor_stage[tumor_stage == "IIIStage"] <- "III+IV"
tumor_stage[tumor_stage == "IVStage"] <- "III+IV"

# add tumor stage to covs
covs_2$tumor_stage <- tumor_stage
covs_2$tumor_stage <- factor(covs_2$tumor_stage, levels = c("I+II", "III+IV"))

# index for oral & laryngeal tumors only 
covs_oral <- covs_2[covs_2$icd_10 == "C02.1" | covs_2$icd_10 == "C02.2" | covs_2$icd_10 == "C02.9" 
                  | covs_2$icd_10 == "C03.0" | covs_2$icd_10 == "C03.1" | covs_2$icd_10 == "C03.9"
                  | covs_2$icd_10 == "C04.0" | covs_2$icd_10 == "C04.9" | covs_2$icd_10 == "C05.0"
                  | covs_2$icd_10 == "C05.9" | covs_2$icd_10 == "C06.0" | covs_2$icd_10 == "C06.2"
                  | covs_2$icd_10 == "C06.9" | covs_2$icd_10 == "C14.8",]

covs_larynx <- covs_2[covs_2$icd_10 == "C32.1" | covs_2$icd_10 == "C32.9",]

# drop subjects w/o BLID expression 
covs_oral_2 <- covs_oral[-which(covs_oral$blid_continuous==-Inf),]
covs_oral_2$blid_continuous

saveRDS(covs_oral_2, file = "05_TCGA_expression_survival_analyses/Data_files/TCGA_oral_cancer_covs_cleaned_w_BLID_expression2.rds")
saveRDS(covs_larynx, file = "05_TCGA_expression_survival_analyses/Data_files/TCGA_larynx_cancer_covs_cleaned_w_SH3BP4_expression2.rds")
