#!/usr/bin/env Rscript
library(tidyverse)
library(reshape2)
library(gprofiler2)
library(ggrepel)
library(gghighlight)

#drop unnecessary columns
output060 <- read_csv("Timeline_project/1_data/ExPecto/output060.csv")
output60100 <- read_csv("Timeline_project/1_data/ExPecto/output60100.csv")
output100200 <- read_csv("Timeline_project/1_data/ExPecto/output100200.csv")
output200300 <- read_csv("Timeline_project/1_data/ExPecto/output200300.csv")
output300500 <- read_csv("Timeline_project/1_data/ExPecto/output300500.csv")
output500800 <- read_csv("Timeline_project/1_data/ExPecto/output500800.csv")
output <- read_csv("Timeline_project/1_data/ExPecto/outputall.csv")

#select columns
select_n_plot <- function (out, whichtitleplot) {	
	#Discard from tin also the first ten columns!!!!!
	tin <- out %>% 
	select(3,8,9, 10, 11, 12, 13, 14, 15, 16,17,18,20, 42, 61, 136, 145, 161, 186, 187, 189, 209) 
	#3,8:20 = gtex, minus 19 (spinal cord)
	colnames(out)
	tin <- melt(tin)
	#positive and negative value filtering, since they are two different columns
	pos <- tin %>% 
		dplyr::filter(value >= 0)
	neg <- tin %>% 
		dplyr::filter(value <= 0)
	#Aggregate values per column
	one <- aggregate(value ~ variable, pos, sum)
	neg <- aggregate(value ~ variable, neg, sum)
	one$negval <- neg$value
	#get them in one place, melt, rename a duplicated column name to reflect +0 or -0 value
	inp <- one
	inp <- melt(inp)
	colnames(inp)[2] <- "group"
	#order values
	inp2 <- inp %>%
	group_by(group) %>% 
	arrange(value, by_group = TRUE) %>%
	mutate(variable=factor(variable, levels=unique(variable)))
	inp2$variable <- fct_rev(inp2$variable)
	#Plot
	p <- ggplot(inp2,aes(x=value,y=variable, fill = group))+
		theme_minimal() +
		geom_bar(stat="identity") +
		labs(title=whichtitleplot,
		 x = "Predicted expression (logFC)",
	 	y = "Structure", 
	 	fill = "Expression") +
		scale_fill_discrete(labels=c("Upregulation", "Downregulation"))
	
	#Print
	pdf(paste0(whichtitleplot, "_1.pdf"))
	print(p)
	dev.off()
	
	#Alternative plot
	#test if same structures:
	one$variable == neg$variable
	#create alternative dataframe
	alt <- NULL
	alt$variable <- one$variable
	alt$value <- c(one$value+neg$value)
	alt$database <- c(rep("GTEX", 14), "Road map", rep("Encode", 7))
	alt <- as.data.frame(alt)
	#arrange
	alt <- alt %>%
	arrange(value) %>%
	mutate(variable=factor(variable, levels=unique(variable)))
	#plot!
	p <- ggplot(alt,aes(x=value,y=variable, fill = database))+
		theme_minimal() +
		geom_bar(stat="identity") +
		labs(title=whichtitleplot, 
	 	x = "Sum of Predicted expression (logFC)",
	 	y = "Structure", 
	 	fill = "Expression")
	#Print
	pdf(paste0(whichtitleplot, "_2.pdf"))
	print(p)
	dev.off()
	return(alt)
}

zero60 <- select_n_plot(output060[,-(1:10),drop=FALSE], "0-60k")
sixty100 <- select_n_plot(output60100[,-(1:10),drop=FALSE], "60-100k")
hundred200 <- select_n_plot(output100200[,-(1:10),drop=FALSE], "100-200k")
twohundred300 <- select_n_plot(output200300[,-(1:10),drop=FALSE], "200-300k")
threehundred500 <- select_n_plot(output300500[,-(1:10),drop=FALSE], "300-500k")
fivehundred80 <- select_n_plot(output500800[,-(1:10),drop=FALSE], "500-800k")

# Integrated figure data processing
rm(allexpr)
allexpr <- full_join(zero60, sixty100)
allexpr <- full_join(allexpr, hundred200)
allexpr <- full_join(allexpr, twohundred300)
allexpr <- full_join(allexpr, threehundred500)
allexpr <- full_join(allexpr, fivehundred80)
windows <-c("0-60kya", "60-100kya", 
            "100-200kya", "200-300ya", 
            "300-500kya", "500-800kya")
allexpr$time <- unlist(lapply(windows, rep, 22))
allexpr$time <- factor(allexpr$time, levels = unique(allexpr$time))

#filter specific points 
highlights <- allexpr %>% 
    filter(value > 0.3 | value < -1 | 
             (time == c("60-100kya") & value < c(-0.4)) |
             (time == c("100-200kya") & value < c(-0.3)) |
             (time == c("0-60kya") & value < c(-0.4)))
highlights$variable <- str_remove_all(highlights$variable, ".. GTEx")


pdf("fig3A.pdf", width = 12, height = 8)
ggplot(allexpr, aes(x=time, y=value, group = variable)) +
  theme_minimal() +
  theme(legend.position = "top") +
  geom_line( color="grey") +
  geom_point( color="black") +
  geom_point(data = highlights, aes(x=time,y=value), color="red") +
  geom_label_repel(data = highlights, 
                   aes(x=time,y=value, label = variable), 
                   nudge_x = 0.1, nudge_y = -0.1, 
                   label.size = 0.05) +
  labs(title="", x = "Time window",
       y = "Sum of variant predicted expression (logFC)")
dev.off()

#As for gene-wise plots...
  genewiseplot <- function(originalout) {
    #Select as before, reshape
    output <- originalout %>% 
    select(3,8,9, 10, 11, 12, 13, 14, 15, 16,17,18,20, 42, 61, 136, 145, 161, 186, 187, 189, 209)  %>% 
    melt()
  
    #Keep the gene!
    output$genes <- originalout$gene
  
    #Variation potential +directionality = value here
  	inp <- aggregate(value ~ genes, output, sum)
  	colnames(inp)[2] <- "directionality"
  
  	#Variation potential magnitude to a new dataframe (inpm+number of time window)
  	inpm <- aggregate(abs(value) ~ genes, output, sum)
  	colnames(inpm)[2] <- "magnitude"
  	
  	#Testing íf columns are the same
  	#Replies with FALSE here if everything ok to merge
  	test <- inp$genes == inpm$genes
  	FALSE %in% test
  
  	#adds magnitude, removes aggregate 
  	inp$magnitude <- inpm$magnitude
  	return(inp)
  }
  
  inp1 <- genewiseplot(output060)
  inp2 <- genewiseplot(output60100)
  inp3 <- genewiseplot(output100200)
  inp4 <- genewiseplot(output200300)
  inp5 <- genewiseplot(output300500)
  inp6 <- genewiseplot(output500800)
  
  plotinp <- rbind(inp1, inp2, inp3, inp4, inp5, inp6)
  plotinp$timing <- c(rep("0 - 60k", nrow(inp1)),
                      rep("60k - 100k", nrow(inp2)),
                      rep("100k - 200k", nrow(inp3)),
                      rep("200k - 300k", nrow(inp4)),
                      rep("300k - 500k", nrow(inp5)),
                      rep("500k - 800k", nrow(inp6)))
  
  
  #order levels 
  plotinp$timing <- factor(plotinp$timing, levels = c("0 - 60k", "60k - 100k", "100k - 200k", "200k - 300k", "300k - 500k", "500k - 800k"))
  
  #clean a bit
  rm(inp1, inp2, inp3, inp4, inp5, inp6, output060, output100200, output200300, output300500, output500800)
  
  genenames<- gconvert(query = plotinp$genes, organism = "hsapiens",
                       target="ENSG", filter_na = FALSE)
  
  test <- genenames$input == plotinp$genes
  FALSE %in% test # should be FALSE
  #produces some NA! some ensemble ID genes are not recognized for some reason (71 genes)
  #I can live with that
  plotinp$genes <- as.character(genenames$name)
  
  #Plots a cone
  pdf("genewise.pdf")
  ggplot(plotinp, aes(x=magnitude, y=directionality, colour = timing, label = genes)) +
    theme_minimal() +
    geom_point(size = 2) +
    labs(x= "Absolute magnitude of change", y = "Directionality (altternative allele)")
    geom_label_repel(data = subset(plotinp,  magnitude > 2), colour = "black", nudge_y = 1 ) 
  dev.off()
  
  
#Overall Q-Q plot
out <- output[,-(1:10),drop=FALSE]
out <- melt(out)

out <- out %>% 
  group_by(variable) %>% 
  summarize(sum = sum(as.numeric(value)))

#Quantile / quantile distribution
pdf("alltissuesQQ.pdf")
ggplot(out, aes(sample=sum)) + 
  theme_minimal() +
  ggtitle("Q-Q plot - extreme value skewedness", subtitle = "ExPecto (all time windows - all tissues)") +
  geom_qq() +
  stat_qq_line()
dev.off()

out <- output[,-(1:10),drop=FALSE]
out <- out%>% 
    select(3,8,9, 10, 11, 12, 13, 14, 15, 16,17,18,20, 42, 61, 136, 145, 161, 186, 187, 189, 209) 
out <- melt(out)

out <- out %>% 
  group_by(variable) %>% 
  summarize(sum = sum(as.numeric(value)))

pdf("braintissuesQQ.pdf")
ggplot(out, aes(sample=sum)) + 
    theme_minimal() +
    ggtitle("Q-Q plot - extreme value skewedness", subtitle = "ExPecto (all time windows - only brain tissues)") +
    geom_qq() +
    stat_qq_line()
dev.off()

#Now for the cone plots
rm(list = ls())

#Import
output060 <- read_csv("Timeline_project/1_data/ExPecto/output060.csv")
output60100 <- read_csv("Timeline_project/1_data/ExPecto/output60100.csv")
output100200 <- read_csv("Timeline_project/1_data/ExPecto/output100200.csv")
output200300 <- read_csv("Timeline_project/1_data/ExPecto/output200300.csv")
output300500 <- read_csv("Timeline_project/1_data/ExPecto/output300500.csv")
output500800 <- read_csv("Timeline_project/1_data/ExPecto/output500800.csv")

#select columns

dataprep <- function (timewindow) {
  output <- timewindow[,-(1:10),drop=FALSE] 
  
  output <- output %>% 
    select(3,8,9, 10, 11, 12, 13, 14, 15, 16,17,18,20, 42, 61, 136, 145, 161, 186, 187, 189, 209) %>% 
    melt()
  output$genes <- timewindow$gene
  
  inp <- aggregate(value ~ genes, output, sum)
  colnames(inp)[2] <- "directionality"
  
  inpm <- aggregate(abs(value) ~ genes, output, sum)
  colnames(inpm)[2] <- "magnitude"
  
  test <- inp$genes == inpm$genes
  FALSE %in% test
  inp$magnitude <- inpm$magnitude
  return(inp)
}

output060 <- dataprep(output060)
output60100 <- dataprep(output60100)
output100200 <- dataprep(output100200)
output200300 <- dataprep(output200300)
output300500 <- dataprep(output300500)
output500800 <- dataprep(output500800)

plotinp <- rbind(output060, output60100, output100200, output200300, output300500, output500800)
plotinp$timing <- c(rep("0 - 60k", nrow(output060)),
                    rep("60k - 100k", nrow(output60100)),
                    rep("100k - 200k", nrow(output100200)),
                    rep("200k - 300k", nrow(output200300)),
                    rep("300k - 500k", nrow(output300500)),
                    rep("500k - 800k", nrow(output500800)))


#order levels 
plotinp$timing <- factor(plotinp$timing, levels = c("0 - 60k", "60k - 100k", "100k - 200k", "200k - 300k", "300k - 500k", "500k - 800k"))

#clean a bit
rm(output060, output60100, output100200, output200300, output300500, output500800)

genenames<- gconvert(query = plotinp$genes, organism = "hsapiens",
                     target="ENSG", filter_na = FALSE)

test <- genenames$input == plotinp$genes
FALSE %in% test # should be FALSE
plotinp$genes <- as.character(genenames$name)

#plot like in the Expecto paper
pdf("allconeplot.pdf")
ggplot(plotinp, aes(x=magnitude, y=directionality, colour = timing, label = genes)) +
  theme_minimal() +
  geom_point(size = 3) +
  labs(x= "Absolute magnitude of change", y = "Directionality (altternative allele)") +
  geom_label_repel(data = subset(plotinp,  magnitude > 2), colour = "black", nudge_y = 1 ) 
dev.off()

pdf("wrapped.pdf")
ggplot(plotinp, aes(x=magnitude, y=directionality, colour = timing, label = genes)) +
  theme_minimal() +
  geom_point(size = 3) +
  labs(x= "Absolute magnitude of change", y = "Directionality (altternative allele)") +
  geom_label_repel(data = subset(plotinp,  magnitude > 2), colour = "black", nudge_y = 1 ) +
  facet_wrap(timing ~ ., ncol = 2)
dev.off()
