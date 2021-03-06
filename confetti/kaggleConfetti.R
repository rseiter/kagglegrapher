# Kaggle Leaderboard Confetti Graph
require(ggplot2)

temp <- c("columbia-university-introduction-to-data-science-fall-2012", TRUE, "12/10/2012")
#temp <- c("traveling-santa-problem", FALSE, "12/20/2012")
#temp <- c("DarkWorlds", FALSE, "12/8/2012")
#temp <- c("GiveMeSomeCredit", TRUE, "11/15/2011")
#temp <- c("ChessRatings2", FALSE)
#temp <- c("FacebookRecruiting", TRUE, "7/15/2012")
#temp <- c("asap-aes", TRUE, "5/1/2012")
#temp <- c("us-census-challenge", FALSE, "11/01/2012")


COMP <- temp[1]
BIGGER_BETTER <- temp[2]
MAXDATE <- strptime(temp[3], "%m/%d/%Y")

filename <- paste("../leaderboards/", COMP, "_public_leaderboard.csv", sep="")
TITLE <- "Columbia Intro Data Science 2012, Kaggle Competition"
output <- paste(COMP, "confettiboard.png", sep="_")


if (BIGGER_BETTER) {
    best <- max
    cumbest <- cummax
    whichway <- "Score\nHigher is Better ->"
} else {
    best <- min
    cumbest <- cummin
    whichway <- "Score\n<- Lower is Better"
}

#Load the main data
scores <- read.csv(filename)
scores$SubmissionDate <- strptime(scores$SubmissionDate, "%m/%d/%Y %r", tz="UTC")
scores$day <- as.Date(trunc(scores$SubmissionDate, units="days"))
scores <- scores[order(scores$SubmissionDate), ]
scores$besttodate <- cumbest(scores$Score)

mindate <- min(scores$SubmissionDate)
maxdate <- max(scores$SubmissionDate)
xrange <- c(as.Date(mindate), as.Date(MAXDATE))

if(BIGGER_BETTER) {
    yrange <- c(quantile(scores$Score)[1], max(scores$Score))
} else {
    yrange <- c(min(scores$Score), quantile(scores$Score)[4])
}

dates <- seq(trunc(xrange[1], units="days"), trunc(xrange[2], units="days"), by=1)
fakedate <- dates[length(dates)]

getbest <- function(Df) c(best=best(Df$Score))
daily_best <- ddply(scores, .(TeamName, day), getbest)
teams <- ddply(scores, .(TeamName), getbest)

scores$teamfac <- factor(scores$TeamName, levels = teams$TeamName[order(teams$best)], ordered=TRUE)

augmented <- daily_best
for (TeamName in unique(scores$TeamName)) {
    currScore <- best(scores$Score[scores$TeamName==TeamName])
    augmented <- rbind(augmented, data.frame(TeamName=TeamName, day=fakedate, V1=currScore))
}

getactivity <- function(Df) c(c(improvements=nrow(Df), dailybest=best(Df$Score)), quantile(Df$besttodate, probs=c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)))
activity <- ddply(scores, .(as.POSIXct(SubmissionDate)), getactivity)
activity <- rename(activity, c( "as.POSIXct(SubmissionDate)"="day"))
activity$besttodate <- cumbest(activity$dailybest)


cumquantile <- function(x) {
    tmp <- c()
    for (i in 1:length(x))
        tmp <- c(tmp, quantile(x[1:i], probs=c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)))
    df <- data.frame(matrix(tmp, ncol=7, byrow=TRUE))
    colnames(df) <- c("0%", "10%", "25%", "50%", "75%", "90%", "100%")
    return(df)
}
scoredist <- cbind(scores, cumquantile(scores$Score))[, c("SubmissionDate", "0%", "10%", "25%", "50%", "75%", "90%", "100%")]
if (BIGGER_BETTER) {
    scoredist <- rename(scoredist, c("100%"="q_0", "90%"="q_1", "75%"="q_2", "50%"="q_3"))
} else {    
    scoredist <- rename(scoredist, c("0%"="q_0", "10%"="q_1", "25%"="q_2", "50%"="q_3"))
}
mtextdf <- data.frame(x=rep(as.POSIXct(fakedate), 4),
                    y=unlist(scoredist[nrow(scoredist), c("q_0", "q_1", "q_2", "q_3")]),
                    label=c("Leader", "90th", "75th", "50th"))
                                    
                                    

bestscore <- best(scores$Score)
extrarow <- activity[nrow(activity), ]
extrarow$day <- fakedate
extrarow$improvements <- 0
extrarow$dailybest <- 0
extrarow$besttodate <- bestscore
activity <- rbind(activity, extrarow)

improvements <- scores[scores$besttodate==scores$Score, ]
improvements <- rbind(improvements, improvements[nrow(improvements), ])
improvements[nrow(improvements), ]$SubmissionDate <- maxdate





#daily_max_graph <- ggplot(activity, aes(day, maxtodate)) + geom_step() + scale_x_date(limits=xrange)
#daily_activity_graph <- ggplot(activity, aes(day, V1)) + geom_bar(stat="identity") + scale_x_date(limits=xrange)

#augmented$offleader <- with(merge(augmented, activity, by="day", all=TRUE), V1.x - maxtodate)
#ggplot(augmented, aes(x=day, y=offleader, colour=TeamName)) + geom_step()  + scale_x_date(limits=xrange) + scale_y_log10()
#ggplot(augmented, aes(x=day, y=sqrt(V1), colour=TeamName)) + geom_step()  + scale_x_date(limits=xrange)

png(output, width=900, height=506)
ggplot(improvements, aes(x=as.POSIXct(SubmissionDate), y=Score, colour=TeamName, group=1)) +
    geom_step(size=1.5) +
    scale_x_datetime(limits=as.POSIXct(xrange)) +
    scale_y_continuous(limits=yrange) +
    geom_smooth(data=scoredist, size=1, colour="grey", aes(x=SubmissionDate, y=q_1)) +
    geom_smooth(data=scoredist, size=1, colour="grey", aes(x=SubmissionDate, y=q_2)) +
    geom_smooth(data=scoredist, size=1, colour="grey", aes(x=SubmissionDate, y=q_3)) +
    geom_point(data=scores, aes(as.POSIXct(SubmissionDate), Score, colour=TeamName, group=TeamName),
               size=1.5) + 
    geom_text(data=mtextdf, aes(x, y, label=label), colour="#111111", size=3.75, hjust=0) +
    geom_text(data=data.frame(x=as.POSIXct(fakedate), y=yrange[2], label="Percentile"),
              aes(x, y, label=label), colour="black", size=5, vjust=-.35, hjust=.675) +
    ggtitle(COMP) + 
    xlab("Submission Date") + 
    theme(legend.position="none"
          ,plot.background = element_blank()
          ,panel.grid.minor = element_blank()
          ,panel.grid.major.y = element_blank()
          ,panel.grid.major.x = element_line(colour="grey")
          ,panel.border = element_blank()
          ,panel.background = element_blank()
          ,axis.line = element_line(colour="grey")
          ,text = element_text(family="Tahoma")) 
dev.off()
print(output)