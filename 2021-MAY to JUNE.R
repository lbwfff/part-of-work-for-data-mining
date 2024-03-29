#TCGA-GTEx
##data capture

rm(list= ls())
library(data.table)
library(DESeq2)

pd <- fread("TCGA-GBM.GDC_phenotype.tsv.gz") #data from UCSC Xena GDC TCGA Glioblastoma dataset: phenotype version08-08-2019
pd <- as.data.frame.matrix(pd)

exp <- fread("TCGA-GBM.htseq_fpkm.tsv.gz") #data from UCSC Xena GDC TCGA Glioblastoma dataset: gene expression RNAseq - HTSeq - FPKM version07-19-2019
exp <- as.data.frame.matrix(exp)
rownames(exp)=exp[,1]
exp=exp[,-1]

pd<-pd[pd$submitter_id.samples %in% colnames(exp),]
pd<-rbind(pd[pd$sample_type.samples=='Primary Tumor',],pd[pd$sample_type.samples=='Solid Tissue Normal',])

a<-exp[,colnames(exp) %in% pd[pd$sample_type.samples=='Primary Tumor',]$submitter_id.samples]
b<-exp[,colnames(exp) %in% pd[pd$sample_type.samples=='Solid Tissue Normal',]$submitter_id.samples]
GBM<-cbind(a,b)

GBM<- (2^GBM - 1)

FPKM2TPM <- function(fpkm){
  exp(log(fpkm) - log(sum(fpkm)) + log(1e6))
}
TPMs <- apply(GBM,2,FPKM2TPM)

pd <- fread("GTEX_phenotype") #data from UCSC Xena GTEx dataset: phenotype - GTEX phenotype version2016-05-18
pd <- as.data.frame.matrix(pd)
table(pd[,3])
fix(pd)
a=pd[pd$primary_site=='Brain',]
a=pd[pd$`body_site_detail (SMTSD)`=='Brain - Cortex',]
list2<-a$Sample

norm <- fread("gtex_RSEM_gene_tpm.gz") #data from UCSC Xena GTEx dataset: gene expression RNAseq - TOIL RSEM tpm version2016-04-19
norm <- as.data.frame.matrix(norm)
norm[1:5,1:5]
rownames(norm)<-norm[,1]
norm<-norm[,-1]
norm<-norm[colnames(norm) %in% list2]
ensembl_id <- substr(row.names(norm),1,15)
rownames(norm) <- ensembl_id

ensembl_id <- substr(row.names(TPMs),1,15)
rownames(TPMs) <- ensembl_id

table(rownames(norm) %in% rownames(TPMs))
norm<-norm[rownames(norm) %in% rownames(TPMs),]
TPMs<-TPMs[rownames(TPMs) %in% rownames(norm),]

norm[1:5,1:5]

b<-TPMs[order(rownames(TPMs),decreasing = T),]
c<-norm[order(rownames(norm),decreasing = T),]
c <- (2^c - 0.001)

identical(rownames(b),rownames(c))
exp<-cbind(b,c)

options(stringsAsFactors = F)

dir.create("SampleFiles")
filepath<-dir(path = "gdc_download_20210604_055103/",full.names=T) #data from TCGA GDC Data Portal Project:TCGA-LGG Cases n=511
for(wd in filepath){
  files <-dir(path = wd,pattern="gz$")
  fromfilepath <- paste(wd,"\\",files,sep="")
  tofilepath <- paste(".\\SampleFiles\\",files,sep="")
  file.copy(fromfilepath,tofilepath)
}

setwd(".\\SampleFiles")
countsFiles<-dir(path=".\\",pattern="gz$")
library(R.utils)
sapply(countsFiles,gunzip)

rm(list = ls())
library(rjson)
metadata_json_File <- fromJSON(file="..\\metadata.cart.2021-06-04.json")
json_File_Info <- data.frame(fileName = c(),TCGA_Barcode = c())
for(i in 1:length(metadata_json_File)){
  TCGA_Barcode <- metadata_json_File[[i]][["associated_entities"]][[1]][["entity_submitter_id"]]
  file_name <- metadata_json_File[[i]][["file_name"]]
  json_File_Info <- rbind(json_File_Info,data.frame(filesName=file_name,TCGA_Barcode=TCGA_Barcode))
}
rownames(json_File_Info) <- json_File_Info[,1]
write.csv(json_File_Info,file ="..\\jiso_File_Info.csv" )

filesName_To_TCGA_BarcodeFile <- json_File_Info[-1]
countsFileNames<-dir(pattern = "txt$")

allsampleRawCounts <- data.frame()
for (txtFile in countsFileNames) {
  SampleCounts <- read.table(txtFile,header=F)
  rownames(SampleCounts) <- SampleCounts[,1]
  SampleCounts <- SampleCounts[-1]
  colnames(SampleCounts) <- filesName_To_TCGA_BarcodeFile[paste(txtFile,".gz",sep = ""),"TCGA_Barcode"]
  if (dim(allsampleRawCounts)[1]==0){
    allsampleRawCounts <- SampleCounts
  }
  else
  {allsampleRawCounts<- cbind(allsampleRawCounts,SampleCounts)}
}
write.csv(allsampleRawCounts,file = "..\\allSampleRawCounts.csv")
head(allsampleRawCounts)
ensembl_id <- substr(row.names(allsampleRawCounts),1,15)
rownames(allsampleRawCounts) <- ensembl_id

write.csv(allsampleRawCounts,file = "..\\RawCounts.csv")

library(TCGAbiolinks)
query <- GDCquery(project = "TCGA-LGG",
                  data.category = "Transcriptome Profiling",
                  data.type = "Gene Expression Quantification",
                  workflow.type = "HTSeq - FPKM")
sampleDown <- getResults(query,cols = c("cases"))

dataSmTP <- TCGAquery_SampleTypes(barcode = sampleDown,typesample = "TP")
dataSmNT <- TCGAquery_SampleTypes(barcode = sampleDown,typesample = "NT")

dataSmTP<-dataSmTP[dataSmTP %in% colnames(allsampleRawCounts)]
Counts<- data.frame(c(allsampleRawCounts[,dataSmNT],allsampleRawCounts[,dataSmTP]))
rownames(Counts) <-row.names(allsampleRawCounts)
colnames(Counts) <-c(dataSmNT,dataSmTP)
LGG=Counts
LGG=LGG[rownames(LGG)%in% rownames(exp),]
LGG=LGG[order(rownames(LGG),decreasing = T),]
exp=exp[order(rownames(exp),decreasing = T),]
identical(rownames(LGG),rownames(exp))

FPKM2TPM <- function(fpkm){
  exp(log(fpkm) - log(sum(fpkm)) + log(1e6))
}
LGG <- apply(LGG,2,FPKM2TPM)

edata<-cbind(exp[,156:265],LGG,exp[,1:155])

##plot

group_list<-c(rep('NORMAL',110),rep('LGG',511),rep('GBM',155))
group_list=as.factor(group_list)
IWANT=rbind(edata[rownames(edata)=='ENSG00000164548',],
            edata[rownames(edata)=='ENSG00000165819',],
            edata[rownames(edata)=='ENSG00000136527',])
rownames(IWANT)<-c('TRA2A','METTL3','TRA2B')
library(reshape2)
IWANT<-as.matrix(IWANT)
IWANT_L=melt(IWANT)
colnames(IWANT_L)=c('E-ID','sample','value')
IWANT_L$group<-c(rep('NORMAL',110*3),rep('LGG',511*3),rep('GBM',155*3))
try=IWANT_L

library(ggplot2)
library(ggsignif)
library(ggsci)
library(ggpubr)

cols<-c('#36537155', "#96345A74")
pal<-colorRampPalette(cols)
image(x=1:20,y=1,z=as.matrix(1:20),col=pal(3))
colors  = pal(3)

ptext<-paste0("Anova, p=",compare_means(value~group,try[try$`E-ID`=='TRA2A',],method = "anova")[[3]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(try[try$`E-ID`=='TRA2A',], aes(x=group, y=log2(value)))+
  geom_violin(aes(colour=group),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
  geom_jitter(aes(fill=group),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
  geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
  labs(y="TRA2A  log2(TPM)")
  #stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
  scale_colour_manual(values=c(colors))+
  scale_fill_manual(values=c(colors))+
  theme(legend.position = "none")+
  theme(axis.text=element_text(size=18),
        axis.title=element_text(size=22))+
  annotate('text',x=0.9,y=7.1,label=dat_text,colour = "black",size=6)+
  annotate('text',x=0.9,y=7.6,label=' Normal N=110
LGG N=511
GBM N=155',colour = "black",size=6)+
  ggsave( file='TCGA-TRA2A.pdf', width=8, height=7)

ptext<-paste0("Anova, p=",compare_means(value~group,try[try$`E-ID`=='METTL3',],method = "anova")[[3]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(try[try$`E-ID`=='METTL3',], aes(x=group, y=log2(value)))+
  geom_violin(aes(colour=group),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
  geom_jitter(aes(fill=group),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
  geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
  labs(y="METTL3  log2(TPM)")
#stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
  scale_colour_manual(values=c(colors))+
  scale_fill_manual(values=c(colors))+
  theme(legend.position = "none")+
  theme(axis.text=element_text(size=18),
        axis.title=element_text(size=22))+
  coord_cartesian(ylim=c(2.4,7.3))+
  annotate('text',x=0.9,y=6.4,label=dat_text,colour = "black",size=6)+
  annotate('text',x=0.9,y=7.0,label=' Normal N=110
LGG N=511
GBM N=155',colour = "black",size=6)+
  ggsave( file='TCGA-METTL3.pdf', width=8, height=7)
  
cor<-rbind(edata[rownames(edata)=='ENSG00000164548',],edata[rownames(edata)=='ENSG00000165819',])
rownames(cor)=c('TRA2A','METTL3')
cor=as.data.frame(t(cor))
cor$group=c(group_list)
NT=cor[cor$group=='3',]
LGG=cor[cor$group=='2',]
GBM=cor[cor$group=='1',]

C<-cor.test(LGG$TRA2A,LGG$METTL3,method='pearson')
D<-cor(LGG$TRA2A,LGG$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = LGG,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=LGG,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=16,y=175,label='LGG N=511',colour = "black",size=6)+
  annotate('text',x=16,y=185,label=ptext,colour = "black",size=6)+
  ggsave(file='TP-cor-TCGALGG.PDF',width = 10,height = 8)
 
C<-cor.test(cor$TRA2A,cor$METTL3,method='pearson')
D<-cor(cor$TRA2A,cor$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = cor,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=cor,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=16,y=175,label='Sample N=776',colour = "black",size=6)+
  annotate('text',x=16,y=185,label=ptext,colour = "black",size=6)+
  ggsave(file='TOTAL-cor-TCGAGTEx.PDF',width = 10,height = 8)

C<-cor.test(NT$TRA2A,NT$METTL3,method='pearson')
D<-cor(NT$TRA2A,NT$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = NT,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=NT,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=16,y=64,label='Normal N=110',colour = "black",size=6)+
  annotate('text',x=16,y=75,label=ptext,colour = "black",size=6)+
  ggsave(file='NT-cor-TCGAGTEx.PDF',width = 10,height = 8)
  
C<-cor.test(GBM$TRA2A,GBM$METTL3,method='pearson')
D<-cor(GBM$TRA2A,GBM$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = GBM,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=GBM,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=16,y=110,label='Normal N=155',colour = "black",size=6)+
  annotate('text',x=16,y=120,label=ptext,colour = "black",size=6)+
  ggsave(file='TP-cor-TCGAGBM.PDF',width = 10,height = 8)


#CGGA

e325<-read.table('CGGA.mRNAseq_325.RSEM-genes.20200506.txt',header = T,sep = '\t') #data from CGGA DataSet ID: mRNAseq_325 Data type: mRNA sequencing Expression Data from STAR+RSEM
rownames(e325)=e325[,1]
e325=e325[,-1]
FPKM2TPM <- function(fpkm){
  exp(log(fpkm) - log(sum(fpkm)) + log(1e6))
}
e325 <- apply(e325,2,FPKM2TPM)

edata<-cbind(exp[,156:265],LGG,exp[,1:155])
meta325<-read.table('CGGA.mRNAseq_325_clinical.20200506.txt',header = T,sep = '\t') #data from CGGA DataSet ID: mRNAseq_325 Data type: mRNA sequencing Clinical Data
meta325$METTL3<-c(e325[rownames(e325)=='METTL3',])
meta325$TRA2A<-c(e325[rownames(e325)=='TRA2A',])
dat=meta325
meta325=as.data.frame(cbind(meta325$Grade,meta325$TRA2A))
colnames(meta325)=c('class','value')

normal<-read.table('CGGA_RNAseq_Control_20.txt',header = T,sep = '\t') ##data from CGGA DataSet ID: mRNA sequencing (non-glioma as control) Expression Data from STAR+RSEM
rownames(normal)=normal[,1]
normal=normal[,-1]
normal <- apply(normal,2,FPKM2TPM)
normal=normal[rownames(normal)=='TRA2A',]
normal=as.data.frame(normal)
normal$q=c(rep('Normal',20))
normal=normal[,order(colnames(normal),decreasing = T)]
colnames(normal)=c('class','value')

exp=rbind(meta325,normal)
exp=exp[!is.na(exp$class),]
exp$value=as.numeric(exp$value)

cols<-c('#36537155', "#96345A74")
pal<-colorRampPalette(cols)
image(x=1:20,y=1,z=as.matrix(1:20),col=pal(4))
colors  = pal(4)

library(ggpubr)
ptext<-paste0("Anova, p=",compare_means(value~class,exp,method = "anova")[[3]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(exp, aes(x=class, y=log2(value)))+
               geom_violin(aes(colour=class),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
               geom_jitter(aes(fill=class),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
               geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
               labs(y="TRA2A  log2(TPM)")
             #stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
               scale_colour_manual(values=c(colors))+
               scale_fill_manual(values=c(colors))+
               theme(legend.position = "none")+
               theme(axis.text=element_text(size=18),
                     axis.title=element_text(size=22))+
               annotate('text',x=1.1,y=8,label=dat_text,colour = "black",size=6)+
               annotate('text',x=1.1,y=9,label='Normal N=20
WHO II N=103
WHO III N=79
WHO IV N=139',colour = "black",size=6)+
               ggsave( file='CGGA-TRA2A.pdf', width=8, height=7)

meta325=dat
meta325=as.data.frame(cbind(meta325$Grade,meta325$METTL3))
colnames(meta325)=c('class','value')
normal<-read.table('CGGA_RNAseq_Control_20.txt',header = T,sep = '\t')
rownames(normal)=normal[,1]
normal=normal[,-1]
normal <- apply(normal,2,FPKM2TPM)
normal=normal[rownames(normal)=='METTL3',]
normal=as.data.frame(normal)

normal$q=c(rep('Normal',20))
normal=normal[,order(colnames(normal),decreasing = T)]
colnames(normal)=c('class','value')

exp=rbind(meta325,normal)
exp=exp[!is.na(exp$class),]
exp$value=as.numeric(exp$value)

ptext<-paste0("Anova, p=",compare_means(value~class,exp,method = "anova")[[3]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(exp, aes(x=class, y=log2(value)))+
  geom_violin(aes(colour=class),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
  geom_jitter(aes(fill=class),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
  geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
  labs(y="TRA2A  log2(TPM)")
#stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
  scale_colour_manual(values=c(colors))+
  scale_fill_manual(values=c(colors))+
  theme(legend.position = "none")+
  theme(axis.text=element_text(size=18),
        axis.title=element_text(size=22))+
  annotate('text',x=1.1,y=7.2,label=dat_text,colour = "black",size=6)+
  annotate('text',x=1.1,y=8.0,label='Normal N=20
WHO II N=103
WHO III N=79
WHO IV N=139',colour = "black",size=6)+
  ggsave( file='CGGA-METTL3.pdf', width=8, height=7)

library(survminer)
library(survival)
library(ggpubr)
library(gridExtra)

dat$osm=(dat$OS)/30
dat$osm=floor(dat$osm)
rownames(dat)<-dat$sample
mat<-dat[!is.na(dat$osm)&
           !is.na(dat$Censor..alive.0..dead.1.),]
matt<-mat
med.exp<-median(matt$TRA2A)
more.med.exp.index<-which(matt$TRA2A>=med.exp)
less.med.exp.index<-which(matt$TRA2A< med.exp)
matt$status<-NA
matt$status[more.med.exp.index]<-paste0('High (',length(more.med.exp.index),')')
matt$status[less.med.exp.index]<-paste0('Low (',length(less.med.exp.index),')')

s.fit<-survfit(Surv(osm,Censor..alive.0..dead.1.) ~ status, data = matt)
s.diff<-survdiff(Surv(osm,Censor..alive.0..dead.1.) ~ status, data = matt)

sdata.plot3<-ggsurvplot(s.fit,
                        data=matt,
                        palette="Pastel1",
                        pval = TRUE,
                        pval.method = TRUE,
                        conf.int = TRUE,
                        xlab = 'Time (Month)',
                        ggtheme = theme_survminer(),
                        surv.median.line = 'hv',
                        title=paste0("CGGA-survival"))
plot(sdata.plot3$plot)
ggsave(filename = 'CGGA-325-survival.pdf',width=10, height=8)
surv_diff <- survdiff(Surv(osm,Censor..alive.0..dead.1.) ~ status, data = matt)
p.value <- 1 - pchisq(surv_diff$chisq, length(surv_diff$n) -1)
print(surv_diff)

###CPTAC######
data<-read.table('proteome_normalized.csv',header = T,sep = ',') #data from Wang LB, Karpova A, Gritsenko MA, et al. Cancer Cell. 2021;39(4):509-528.e20.
data=data[!duplicated(data[,1]),]
rownames(data)=data[,1]
data=data[,-(1:3)]

clin<-read.table('Clinical_Data2.csv',header = T,sep = ',',fill = T) #data from cptac-data-portal Clinical Data for CPTAC GBM Cohort 99 Cases
TRA2A=data[rownames(data)=='TRA2A',]
TRA2A <- (2^TRA2A)
TRA2A=as.data.frame(t(TRA2A))
TRA2A$group<-c(rep('GBM',99),rep('Normal',10))
TRA2A$group<- factor(TRA2A$group,levels = c("Normal", "GBM"))

METTL3=data[rownames(data)=='METTL3',]
METTL3 <- (2^METTL3)
METTL3=as.data.frame(t(METTL3))
METTL3$group<-c(rep('GBM',99),rep('Normal',10))
METTL3$group<- factor(METTL3$group,levels = c("Normal", "GBM"))

cols<-c('#36537155', "#96345A74")
pal<-colorRampPalette(cols)
image(x=1:20,y=1,z=as.matrix(1:20),col=pal(2))
colors  = pal(2)

library(ggplot2)
library(ggsignif)
library(ggsci)
library(ggpubr)

compare_means(TRA2A~group,TRA2A,method = "t.test")
ptext<-paste0("t.test, p=",compare_means(TRA2A~group,TRA2A,method = "t.test")[[6]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(TRA2A, aes(x=group, y=log2(TRA2A), fill=group))+
  geom_violin(aes(colour=group),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
  geom_jitter(aes(fill=group),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
  geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
  labs(y="log2(TRA2A)")
#stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
  scale_colour_manual(values=c(colors))+
  scale_fill_manual(values=c(colors))+
  theme(legend.position = "none")+
  theme(axis.text=element_text(size=18),
        axis.title=element_text(size=22))+
  annotate('text',x=0.8,y=1.1,label=dat_text,colour = "black",size=6)+
  annotate('text',x=0.8,y=1.4,label='Normal N=10
GBM N=99',colour = "black",size=6)+
  ggsave( file='CPTAC-TRA2A.pdf', width=8, height=7)

compare_means(METTL3~group,METTL3,method = "t.test")
ptext<-paste0("t.test, p=",compare_means(METTL3~group,METTL3,method = "t.test")[[6]])
dat_text <- data.frame(label = ptext)
dp <- ggplot(METTL3, aes(x=group, y=log2(METTL3), fill=group))+
  geom_violin(aes(colour=group),fill='#DDDDDD50',trim=FALSE,show.legend=FALSE,size=0.7)+
  geom_jitter(aes(fill=group),width =0.2,shape = 21,size=4,colour='NA',alpha = 0.4)+
  geom_boxplot(fill='white',width=0.12,,outlier.shape = NA,size=0.8)+
  labs(y="log2(METTL3)")
#stat_compare_means(label.x = 0.7,size=5)
dp + theme_classic(base_size = 22)+ 
  scale_colour_manual(values=c(colors))+
  scale_fill_manual(values=c(colors))+
  theme(legend.position = "none")+
  theme(axis.text=element_text(size=18),
        axis.title=element_text(size=22))+
  annotate('text',x=0.8,y=0.4,label=dat_text,colour = "black",size=6)+
  annotate('text',x=0.8,y=0.6,label='Normal N=10
GBM N=99',colour = "black",size=6)+
  ggsave( file='CPTAC-METTL3.pdf', width=8, height=7)
  
cor=cbind(TRA2A,METTL3)
cor=cor[,-2]
TP=cor[1:99,]
NT=cor[100:109,]
C<-cor.test(cor$TRA2A,cor$METTL3,method='pearson')
D<-cor(cor$TRA2A,cor$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))
ggplot(data = cor,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  #stat_cor(data=cor,method='pearson',size=6,p.digits = digits)+
  theme_classic()+
  annotate('text',x=0.7,y=2.1,label='Sample N=109',colour = "black",size=6)+
  annotate('text',x=0.7,y=2.2,label=ptext,colour = "black",size=6)+
  ggsave(file='TOTAL-cor-CAPTAC.PDF',width = 10,height = 8)


C<-cor.test(NT$TRA2A,NT$METTL3,method='pearson')
D<-cor(NT$TRA2A,NT$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = NT,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=NT,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=0.64,y=0.8,label='Normal N=10',colour = "black",size=6)+
  ggsave(file='NT-cor-CAPTAC.PDF',width = 10,height = 8)

C<-cor.test(TP$TRA2A,TP$METTL3,method='pearson')
D<-cor(TP$TRA2A,TP$METTL3,method='pearson')
ptext<-paste0("R=",signif(D,2),',','P=',signif(2* pt(C$statistic, df = C$parameter, lower.tail=FALSE),3))

ggplot(data = TP,aes(x=METTL3,y=TRA2A))+
  geom_point(shape=21,size=4)+
  stat_smooth(method = lm)+
  stat_cor(data=TP,method='pearson',size=6)+
  theme_classic()+
  annotate('text',x=0.8,y=2.1,label='Tumor N=99',colour = "black",size=6)+
  ggsave(file='TP-cor-CAPTAC.PDF',width = 10,height = 8)
  
#######CGGA miRNA
rm(list = ls())
stringsAsFactors=FALSE
exp<-read.table('CGGA.microRNA_array_198_gene_level.20200506.txt',header = T,sep = '\t') #data from CGGA DataSet ID: microRNA_198 Expression Data (gene level)
rownames(exp)<-c(paste('r',1:829,sep=''))
mid<-cbind(exp[,199],c(1:829))
mid<-cbind(exp[,199],c(paste('r',1:829,sep='')))

meta<-read.table('CGGA.microRNA_array_198_clinical.20200506.txt',header = T,sep = '\t')  #data from CGGA DataSet ID: microRNA_198 Clinical Data

exp=exp[,order(colnames(exp),decreasing = T)]
exp2=exp[,-1]
rownames(exp2)=rownames(exp)
meta=meta[order(meta[,1],decreasing = T),]
exp2[830,]=meta$Grade
#colnames(exp2)=exp2[830,]
exp2=exp2[,order(exp2[830,],decreasing = F)]
micrna=c(exp$microRNA_ID,'na')

table(meta$Grade)
sample_calss=c(rep('WHO II',60),
               rep('WHO III',47),
               rep('WHO IV',91))
level = c(1:198)
annotation_c <- data.frame(sample_calss, level)
rownames(annotation_c) <- colnames(exp2)
exp3=exp2[-830,]
exp3=as.data.frame(lapply(exp3,as.numeric))
class(exp3)
rownames(exp3)<-c((paste('r',1:829,sep='')))
annotation_b=annotation_c[,-2]
annotation_b=as.data.frame(annotation_b)
rownames(annotation_b)=rownames(annotation_c)
annotation_c=annotation_b

library(pheatmap)
p=pheatmap(exp3,
         cluster_rows = T,
         cluster_cols = F,
         annotation_col =annotation_b,
         annotation_legend=TRUE,
         scale = "row",
         show_rownames = F,
         show_colnames = F,
         breaks = seq(-1,1,length.out = 100))

table(annotation_c$sample_calss)
group_list1<-c(rep('WHOII',60),rep('WHOIII',47))
group_list2<-c(rep('WHOIII',47),rep('WHOIV',91))
group_list1=as.factor(group_list1)
group_list2=as.factor(group_list2)
identical(rownames(annotation_c),colnames(exp3))
EXP1=exp3[,1:107]
EXP2=exp3[,61:198]

library(limma)
design <- model.matrix(~0+factor(group_list1))
colnames(design)=levels(factor(group_list1))
rownames(design)=colnames(EXP1)
design
contrast.matrix<-makeContrasts(WHOIII-WHOII,levels = design)
contrast.matrix 
fit <- lmFit(EXP1,design)
fit2 <- contrasts.fit(fit, contrast.matrix)
fit2 <- eBayes(fit2)  #default no trend !!!
tempOutput = topTable(fit2, coef=1, n=Inf)
nrDEG1 = na.omit(tempOutput) 
head(nrDEG1)

design <- model.matrix(~0+factor(group_list2))
colnames(design)=levels(factor(group_list2))
rownames(design)=colnames(EXP2)
design
contrast.matrix<-makeContrasts(WHOIV-WHOIII,levels = design)
contrast.matrix 
fit <- lmFit(EXP2,design)
fit2 <- contrasts.fit(fit, contrast.matrix)
fit2 <- eBayes(fit2)  #default no trend !!!
tempOutput = topTable(fit2, coef=1, n=Inf)
nrDEG2 = na.omit(tempOutput) 
head(nrDEG2)

identical(rownames(nrDEG2),rownames(nrDEG2))
nrDEG1=nrDEG1[nrDEG1[,1]<0,]
nrDEG2=nrDEG2[nrDEG2[,1]<0,]
nrDEG1=nrDEG1[nrDEG1[,4]<0.05,]
nrDEG2=nrDEG2[nrDEG2[,4]<0.05,]
LIST=nrDEG1[rownames(nrDEG1) %in% rownames(nrDEG2),]
LIST=mid[mid[,2] %in% rownames(LIST),]

fix(LIST)
LIST=LIST[!duplicated(LIST[,1]),]
exp4=exp3[rownames(exp3) %in% LIST[,2],]
rownames(exp4)=LIST[,1]

colnames(annotation_b)<-c('Grade')
fix(exp4)
library(pheatmap)
p=pheatmap(exp4,
           cluster_rows = T,
           cluster_cols = F,
           annotation_col =annotation_b,
           annotation_legend=TRUE,
           scale = "row",
           show_rownames = T,
           show_colnames = F,
           breaks = seq(-1,1,length.out = 100))
write.csv(exp4,file = 'exp4.csv')
