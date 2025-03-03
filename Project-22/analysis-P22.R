#
# analysis-P22.R, 15 Feb 23
#
# Analysis of the Project 22 data, from Company A.

library("colorspace")
library("lubridate")
library("plyr")


par(bty="l")
par(las=1)
par(pch="+")
par(mfcol=c(1, 1))


p22=read.csv("story-info.csv", as.is=TRUE)

p22$IsMCO=ifelse(is.na(p22$IsMCO), 0, 1)
# Who worked on each story
p22$d1t=!is.na(p22$D1)
p22$d2t=!is.na(p22$D2)
p22$d3t=!is.na(p22$D3)
# Story team size
p22$TeamSize=p22$d1t+p22$d2t+p22$d3t
p22$TeamDev=paste0("D", ifelse(p22$d1t, "1", ""), ifelse(p22$d2t, "2", ""), ifelse(p22$d3t, "3", ""))

nonmco=subset(p22, IsMCO == 0)
mco=subset(p22, IsMCO == 1)
mco=subset(mco, StoryPoints > 0)

# Code review info
mco_end_date=as.Date("2022-10-30")

crev=read.csv("review-info.csv", as.is=TRUE)
crev$Date=as.Date(crev$Date)

crev=subset(crev, Date < mco_end_date) # remove outlier

mco_cr=subset(crev, Branch %in% p22$Branch)

mco_cr=subset(mco_cr, ReviewMinutes < 200)

# Sum all reviews for the same Branch
ucrev=ddply(crev, .(Branch), function(df)
				return(data.frame(num_rev=nrow(df),
							total_rev_mins=sum(df$ReviewMinutes, na.rm=TRUE),
							Date=df$Date[1],
							passed=sum(df$PassedReview == "no"),
							failed=sum(df$PassedReview != "no"))))

r_mco=merge(mco, ucrev, by="Branch", all.x=TRUE)

# Around half of the branches are not reviewed
r_mco$num_rev[is.na(r_mco$num_rev)]=0
r_mco$passed[is.na(r_mco$passed)]=0
r_mco$failed[is.na(r_mco$failed)]=0
r_mco$total_rev_mins[is.na(r_mco$total_rev_mins)]=0
r_mco$act_hrs=r_mco$Total+r_mco$total_rev_mins/60

table(r_mco$num_rev)

# Jira sprint info
spr=read.csv("sprint-info.csv", as.is=TRUE)

mco_s=read.csv("mco_stories.csv", as.is=TRUE)

# table(mco$TeamSize, mco$StoryPoints)
#    
#      1  2  3  4  5  6  8
#   1 22 28 30 38 16  3  0
#   2 31 31 32 21 37  0  1
#   3  0  6 13  6  6  0  0

# Number of occurrences of each estimated Story point
pal_col=rainbow(2)

plot(count(r_mco$StoryPoints), type="b", col=pal_col[1], log="x",
	yaxs="i",
	xlim=c(1, 12), ylim=c(0, 80),
	xlab="Story points/Actual (hours)", ylab="Stories")

lines(count(round(r_mco$act_hrs)), type="b", col=pal_col[2])

legend(x="bottomleft", legend=c("Story Points", "Actual (hours)"),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="est_act-count.png")
dev.off()

# plot(count(round(mco$Total*2)/2), log="x")

pal_col=rainbow(4)

plot(r_mco$StoryPoints, r_mco$act_hrs, col=pal_col[3], log="xy",
	xlab="Estimated (story points)", ylab="Actual (hours)")

# # The best fip22ing model is:
# mco_mod=glm(log(act_hrs) ~ log(StoryPoints)+TeamSize, data=r_mco)
mco_mod=glm(log(act_hrs) ~ log(StoryPoints), data=r_mco)
summary(mco_mod)

x_range=1:9

pred=predict(mco_mod, newdata=data.frame(StoryPoints=x_range), se.fit=TRUE)

lines(x_range, exp(pred$fit), col=pal_col[1])

# Estimated story points == Actual hours
lines(x_range, x_range, col="grey")

# Calculate prediction confidence interval
MSE=sum(mco_mod$residuals^2)/(length(mco_mod$residuals)-2)
# Variances, but not sd, can be added
pred_se=sqrt(pred$se.fit^2+MSE)

# One standard deviation, 68.5% confidence interval
x_un=exp(pred$fit+pred_se)/x_range
x_ov=exp(pred$fit-pred_se)/x_range

# One standard deviation, 68.5% confidence interval
lines(x_range, exp(pred$fit+1*pred_se), col=pal_col[4])
lines(x_range, exp(pred$fit-1*pred_se), col=pal_col[4])

# 95% confidence interval, almost two standard deviations
lines(x_range, exp(pred$fit+1.96*pred_se), col=pal_col[2])
lines(x_range, exp(pred$fit-1.96*pred_se), col=pal_col[2])

legend(x="bottomright", legend=c("Fip22ed model", "95% prediction interval", "Tasks", "1 sd (68%) prediction interval"),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="est_act-fip22ed.png")
dev.off()

# Percentage of 'exact' estimates, 1.9%
length(which(r_mco$StoryPoints == r_mco$act_hrs))/nrow(r_mco)

low_1sd=exp(pred$fit)/exp(pred$fit-1*pred_se)
# high_1sd=exp(pred$fit+1*pred_se)/exp(pred$fit)
mean(low_1sd) # all the same
# mean(high_1sd)

low_95=exp(pred$fit)/exp(pred$fit-1.96*pred_se)
# high_95=exp(pred$fit+1.96*pred_se)/exp(pred$fit)
mean(low_95) # all the same
# mean(high_95)

# Frequency of actuals for each possible SP valued

pal_col=rainbow(5)

plot(1, type="n", log="x",
	xaxs="i", yaxs="i",
	xlim=c(0.5, 15), ylim=c(0, 18),
	xlab="Actual (hours)", ylab="Stories")

act_freq_SP=ddply(r_mco, .(StoryPoints),
			function(df)
			{
			cnt_total=count(round(df$act_hrs*2)/2)
			lines(cnt_total, col=pal_col[df$StoryPoints[1]])
			return(cnt_total)
			})

legend(x="topright", legend=paste0(1:5, " SP"),
			bty="n", fill=pal_col, cex=1.2)
dev.copy(dev=png, file="act_hrs_count.png")
dev.off()


# Code review data
t=count(crev$ReviewMinutes)
t=t[order(t$freq, decreasing=TRUE),]
head(t, n=10)
#      x freq
# 16  15  231
# 31  30  179
# 11  10   98
# 61  60   92
# 21  20   87
# 6    5   78
# 46  45   68
# 26  25   32
# 85 120   31
# 80  90   30

pal_col=rainbow(2)

plot(mco_cr$Date, mco_cr$ReviewMinutes, col=pal_col[2], log="y",
		xlab="Date", ylab="Review time (minutes)")

lines(range(mco_cr$Date), c(40, 40), col="grey")

# rev_mod=glm(ReviewMinutes ~ Date, data=crev)
# summary(rev_mod)

lines(loess.smooth(mco_cr$Date, mco_cr$ReviewMinutes, span=0.3), col=pal_col[1])

# plot(ucrev$Date, ucrev$total_rev_mins, col=pal_col[2], log="y",
# 		xlab="Date", ylab="Review time (minutes)")
# rev_mod=glm(ReviewMinutes ~ Date, data=ucrev)
# summary(rev_mod)

lines(loess.smooth(ucrev$Date, ucrev$total_rev_mins, span=0.3), col=pal_col[1])

dev.copy(dev=png, file="rev-mins-date.png")
dev.off()

# dev.copy(dev=png, file="total_rev-date.png")
# dev.off()

# Reviews per day
cr_day=count(mco_cr$Date)
plot(cr_day, col=pal_col[2],
        ylim=c(0, 10),
        xlab="Date", ylab="Reviews per day")
lines(loess.smooth(cr_day$x, cr_day$freq, span=0.3), col=pal_col[1])

dev.copy(dev=png, file="reviews-per-day.png")
dev.off()

# Number of reviews on each day of the week
mco_cr$wday=wday(mco_cr$Date, week_start=1)
plot(count(mco_cr$wday), type="b", col=pal_col[1],
	xaxt="n",
	xlab="Day of week", ylab="Reviews")
axis(1, at=c(1, 3, 5, 7), labels=c("Mon", "Wed", "Fri", "Sun"))

dev.copy(dev=png, file="rev-day-week.png")
dev.off()


plot(r_mco$StoryPoints, r_mco$total_rev_mins, log="xy", col=pal_col[2],
	xlab="Story Points", ylab="Review time (minutes)")

sprev_mod=glm(log(total_rev_mins) ~ log(StoryPoints), data=r_mco)
summary(sprev_mod)

pred=predict(sprev_mod, newdata=data.frame(StoryPoints=x_range))
lines(x_range, exp(pred), col=pal_col[1])

rmco_mod=glm(log(act_hrs) ~ log(StoryPoints)+TeamSize, data=r_mco)
summary(rmco_mod)

# mco stories
mcos_mod=glm(log(Total) ~ log(StoryPoints)+TeamSize+Is.Programming, data=mco)
summary(mcos_mod)

# Story point count for each developer
pal_col=rainbow(3)

allSP=mco$StoryPoints
d1SP=subset(mco, d1t)$StoryPoints
d2SP=subset(mco, d2t)$StoryPoints
d3SP=subset(mco, d3t)$StoryPoints

plot(count(d1SP), col=pal_col[1], type="l",
	xlab="Story points", ylab="Occurrences")
lines(count(d2SP), col=pal_col[2])
lines(count(d3SP), col=pal_col[3])

legend(x="topright", legend=paste0("D", 1:3),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="SP-per-dev.png")
dev.off()


# Does the everage number of story points in a Story vary between developers?

mean_story=function(d_stories, d1_stories, d2_stories)
{
sp1=sample(d_stories, size=d1_stories)
sp2=sample(d_stories, size=d2_stories)
return(mean(sp2) < mean(sp1))
}

d1_mean=mean(d1SP)
d2_mean=mean(d2SP)
d3_mean=mean(d3SP)

c(d1_mean, d2_mean, d3_mean)
c(length(d1SP), length(d2SP), length(d3SP))

# Bootstap comparison of mean differences
d12SP=subset(mco, d1t || d2t)$StoryPoints

d1_boot=replicate(4999, mean_story(d12SP, length(d1SP), length(d2SP)))
table(d1_boot)
# d1_boot
# FALSE  TRUE 
#  2509  2490 


# Actual time per story point
SP_scatterplot=function(df)
{
par(mfcol=c(1, 3))

smoothScatter(df$StoryPoints, df$D1p, colramp=colorRampPalette(hcl.colors(30, palette = "inferno")),
		nbin=50,
		xlab="Story points", ylab="Actual time spent (percent)")
smoothScatter(df$StoryPoints, df$D2p, colramp=colorRampPalette(hcl.colors(30, palette = "inferno")),
		nbin=50,
		xlab="Story points", ylab="Actual time spent (percent)")
smoothScatter(df$StoryPoints, df$D3p, colramp=colorRampPalette(hcl.colors(30, palette = "inferno")),
		nbin=50,
		xlab="Story points", ylab="Actual time spent (percent)")
par(mfcol=c(1, 1))
}

mco$D1p=mco$D1/mco$Total
mco$D2p=mco$D2/mco$Total
mco$D3p=mco$D3/mco$Total


SP_scatterplot(mco)
dev.copy(dev=png, file="SP-act-perc-dev.png")
dev.off()

two_dev=subset(mco, d1t+d2t+d3t == 2)
SP_scatterplot(two_dev)
dev.copy(dev=png, file="SP-act-perc-2devs.png")
dev.off()

# Info on all Sprints for each story
get_all_sprints_stories=function(s_df)
{
# Non-empty string is assumed to be an assigned sprint
num_sprints=ddply(s_df, .(Branch), function(df)
					{
					str=paste(df[ , spr_cols], collapse=" | ")
					# Remove noise created by empty columns
					str=gsub(" \\| NA", "", str)
					str=gsub(" \\|(  \\|)+", " |", str)
					data.frame(count=length(which(df[ , spr_cols] != "")),
							str=gsub(" \\| $", "", str),
							spr_num=as.numeric(str),
							SP=df$StoryPoints)
					})
return(num_sprints)
}


# Summarise information about each sprint
sprint_summary=function(df)
{
spr_info=ddply(df, .(spr_num), function(df)
                                {
                                data.frame(num_stories=nrow(df),
                                                # Amount of over/under estimation
                                                under_est=sum(ifelse(df$StoryPoints < df$act_hrs,
                                                                        df$act_hrs-df$StoryPoints, 0)),
                                                over_est=sum(ifelse(df$StoryPoints > df$act_hrs,
                                                                        df$StoryPoints-df$act_hrs, 0)),
                                                total_SP=sum(df$StoryPoints),
                                                total_act=sum(df$act_hrs),
                                                D1_story=length(which(!is.na(df$D1))),
                                                D2_story=length(which(!is.na(df$D2))),
                                                D3_story=length(which(!is.na(df$D3))),
                                                D1_hr=sum(df$D1, na.rm=TRUE),
                                                D2_hr=sum(df$D2, na.rm=TRUE),
                                                D3_hr=sum(df$D3, na.rm=TRUE)
                                                )
                                })
}


col_names=names(spr)
spr_cols=which(grepl("snum", col_names))


all_sprints=get_all_sprints_stories(spr)

all_sprints=subset(all_sprints, Branch %in% r_mco$Branch)

# s_mco=merge(mco, all_sprints, by="Branch", all=TRUE)
s_mco=merge(r_mco, all_sprints, by="Branch", all=TRUE)

summary_mco_spr=sprint_summary(s_mco)
summary_mco_spr$D123_hr=summary_mco_spr$D1_hr+summary_mco_spr$D2_hr+summary_mco_spr$D3_hr

pal_col=rainbow(3)

plot(summary_mco_spr$spr_num, summary_mco_spr$total_act, col=pal_col[1], type="b",
	xlab="Sprint", ylab="")
lines(summary_mco_spr$spr_num, summary_mco_spr$total_SP, col=pal_col[2], type="b")
lines(summary_mco_spr$spr_num, summary_mco_spr$num_stories, col=pal_col[3], type="b")

legend(x="topleft", legend=c("Actual (total mins)", "Story points (total)", "Stories"),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-summary.png")
dev.off()

plot(summary_mco_spr$spr_num, summary_mco_spr$total_act/summary_mco_spr$total_SP, col=pal_col[3], type="b",
	ylim=c(0.9, 5.5),
	xlab="Sprint", ylab="")
lines(range(summary_mco_spr$spr_num, na.rm=TRUE), c(1, 1), col="grey")

lines(summary_mco_spr$spr_num, summary_mco_spr$total_SP/summary_mco_spr$num_stories, col=pal_col[2], type="b")
lines(summary_mco_spr$spr_num, summary_mco_spr$total_act/summary_mco_spr$num_stories, col=pal_col[1], type="b")

legend(x="top", legend=c("Actual (total mins)/Stories",
				"Story points (total)/Stories",
				"Actual (total mins)/Story points (total)"),
				bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-est_act-ratios.png")
dev.off()

plot(summary_mco_spr$spr_num, summary_mco_spr$D1_story, col=pal_col[1], type="b",
	xlab="Sprint", ylab="Stories")
lines(summary_mco_spr$spr_num, summary_mco_spr$D2_story, col=pal_col[2], type="b")
lines(summary_mco_spr$spr_num, summary_mco_spr$D3_story, col=pal_col[3], type="b")

legend(x="topleft", legend=paste0("D", 1:3, " stories"),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-dev-stories.png")
dev.off()

plot(summary_mco_spr$spr_num, summary_mco_spr$D1_hr/summary_mco_spr$D123, col=pal_col[1], type="b",
	ylim=c(0, 1),
	xlab="Sprint", ylab="Time fraction")
lines(summary_mco_spr$spr_num, summary_mco_spr$D2_hr/summary_mco_spr$D123, col=pal_col[2], type="b")
lines(summary_mco_spr$spr_num, summary_mco_spr$D3_hr/summary_mco_spr$D123, col=pal_col[3], type="b")

legend(x="top", legend=paste0("D", 1:3, " time fraction"),
			bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-dev-act-fract.png")
dev.off()


before_129=subset(s_mco, spr_num < 129)
since_129=subset(s_mco, spr_num >= 129)

plot(count(before_129$StoryPoints), type="b", col=pal_col[1],
        ylim=c(10, 50),
        xlab="Story Points", ylab="Stories")
lines(count(since_129$StoryPoints), type="b", col=pal_col[2])

legend(x="bottom", legend=c("Sprints before 129", "Sprint 129 and later"),
                        bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-129-split.png")
dev.off()

pal_col=rainbow(2)
plot(summary_mco_spr$spr_num, summary_mco_spr$under_est, col=pal_col[1], type="b",
        xlab="Sprint", ylab="Total SP~Hours")
lines(summary_mco_spr$spr_num, summary_mco_spr$over_est, col=pal_col[2], type="b")

legend(x="topleft", legend=c("Under estimates", "Over estimate"),
                        bty="n", fill=pal_col, cex=1.2)

dev.copy(dev=png, file="sprint-over-under-est.png")
dev.off()


