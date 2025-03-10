#Sys.setenv(TRIAL = "janssen_pooled_mock")
if (.Platform$OS.type == "windows") .libPaths(c(paste0(Sys.getenv ("R_HOME"), "/library"), .libPaths()))
#-----------------------------------------------
renv::activate(here::here())
# There is a bug on Windows that prevents renv from working properly. The following code provides a workaround:
if (.Platform$OS.type == "windows") {
  .libPaths(c(paste0(Sys.getenv ("R_HOME"), "/library"), .libPaths()))
}
source(here::here("_common.R"))
#-----------------------------------------------

# packages and settings
library(here)
library(tidyverse)
library(Hmisc) # wtd.quantile, cut2
library(mice)
library(dplyr)

myprint(study_name_code)

dat_proc <- read.csv(here(
  "data_raw", data_raw_dir, data_in_file
))


if(study_name=="MockENSEMBLE") dat_proc=dat_proc[, !contain(names(dat_proc), "pseudoneutid")]

colnames(dat_proc)[1] <- "Ptid" 

dat_proc=subset(dat_proc, !is.na(Bserostatus))

          dat_proc=subset(dat_proc, !is.na(EventTimePrimaryD1) & !is.na(EventTimePrimaryD29))
if(has57) dat_proc=subset(dat_proc, !is.na(EventTimePrimaryD57))

          dat_proc$EarlyendpointD29 <- with(dat_proc, ifelse(EarlyinfectionD29==1 | (EventIndPrimaryD1==1 & EventTimePrimaryD1 < NumberdaysD1toD29 + 7),1,0))
if(has57) dat_proc$EarlyendpointD57 <- with(dat_proc, ifelse(EarlyinfectionD57==1 | (EventIndPrimaryD1==1 & EventTimePrimaryD1 < NumberdaysD1toD57 + 7),1,0))

dat_proc <- dat_proc %>%
  mutate(
    age.geq.65 = as.integer(Age >= 65)
  )

dat_proc$Senior = as.integer(dat_proc$Age>=switch(study_name_code, COVE=65, ENSEMBLE=60, stop("unknown study_name_code")))

  
  
# ethnicity labeling
dat_proc$ethnicity <- ifelse(dat_proc$EthnicityHispanic == 1, labels.ethnicity[1], labels.ethnicity[2])
dat_proc$ethnicity[dat_proc$EthnicityNotreported == 1 | dat_proc$EthnicityUnknown == 1] <- labels.ethnicity[3]
dat_proc$ethnicity <- factor(dat_proc$ethnicity, levels = labels.ethnicity)


# race labeling
if (study_name_code=="COVE") {
    dat_proc <- dat_proc %>%
      mutate(
        race = labels.race[1],
        race = case_when(
          Black == 1 ~ labels.race[2],
          Asian == 1 ~ labels.race[3],
          NatAmer == 1 ~ labels.race[4],
          PacIsl == 1 ~ labels.race[5],
          Multiracial == 1 ~ labels.race[6],
          Other == 1 ~ labels.race[7],
          Notreported == 1 | Unknown == 1 ~ labels.race[8],
          TRUE ~ labels.race[1]
        ),
        race = factor(race, levels = labels.race)
      )
      
} else if (study_name_code=="ENSEMBLE") {
    # remove Other
    dat_proc <- dat_proc %>%
      mutate(
        race = labels.race[1],
        race = case_when(
          Black == 1 ~ labels.race[2],
          Asian == 1 ~ labels.race[3],
          NatAmer == 1 ~ labels.race[4],
          PacIsl == 1 ~ labels.race[5],
          Multiracial == 1 ~ labels.race[6],
          Notreported == 1 | Unknown == 1 ~ labels.race[7],
          TRUE ~ labels.race[1]
        ),
        race = factor(race, levels = labels.race)
      )
}

# WhiteNonHispanic=1 IF race is White AND ethnicity is not Hispanic
dat_proc$WhiteNonHispanic <- NA
dat_proc$WhiteNonHispanic <-
  ifelse(dat_proc$race == "White" &
    dat_proc$ethnicity == "Not Hispanic or Latino", 1,
  dat_proc$WhiteNonHispanic
  )
# WhiteNonHispanic=0 IF race is not "white or unknown" OR ethnicity is Hispanic
dat_proc$WhiteNonHispanic <-
  ifelse(!dat_proc$race %in% c(labels.race[1], last(labels.race)) |
    dat_proc$ethnicity == "Hispanic or Latino", 0,
    dat_proc$WhiteNonHispanic
  )
dat_proc$MinorityInd = 1-dat_proc$WhiteNonHispanic
dat_proc$MinorityInd[is.na(dat_proc$MinorityInd)] = 0
# set MinorityInd to 0 for latin america and south africa
if (study_name_code=="ENSEMBLE") {
    dat_proc$MinorityInd[dat_proc$Region!=0] = 0
}


# check coding via tables
#table(dat_proc$race, useNA = "ifany")
#table(dat_proc$WhiteNonHispanic, useNA = "ifany")
#table(dat_proc$race, dat_proc$WhiteNonHispanic, useNA = "ifany")


## URMforsubcohortsampling is defined in data_raw, the following is a check
#dat_proc$URMforsubcohortsampling <- NA
#dat_proc$URMforsubcohortsampling[dat_proc$Black==1] <- 1
#dat_proc$URMforsubcohortsampling[dat_proc$ethnicity=="Hispanic or Latino"] <- 1
#dat_proc$URMforsubcohortsampling[dat_proc$NatAmer==1] <- 1
#dat_proc$URMforsubcohortsampling[dat_proc$PacIsl==1] <- 1
#dat_proc$URMforsubcohortsampling[dat_proc$Asian==1 & dat_proc$EthnicityHispanic==0 & dat_proc$EthnicityUnknown==0 & dat_proc$EthnicityNotreported==0] <- 0
#dat_proc$URMforsubcohortsampling[dat_proc$Multiracial==1 & dat_proc$EthnicityHispanic==0 & dat_proc$EthnicityUnknown==0 & dat_proc$EthnicityNotreported==0] <- 0
#dat_proc$URMforsubcohortsampling[dat_proc$Other==1 & dat_proc$EthnicityHispanic==0 & dat_proc$EthnicityUnknown==0 & dat_proc$EthnicityNotreported==0] <- 0
## Add observed White Non Hispanic:
#dat_proc$URMforsubcohortsampling[dat_proc$EthnicityHispanic==0 & dat_proc$EthnicityUnknown==0 & dat_proc$EthnicityNotreported==0 & dat_proc$Black==0 & dat_proc$Asian==0 & dat_proc$NatAmer==0 & dat_proc$PacIsl==0 &
#dat_proc$Multiracial==0 & dat_proc$Other==0 & dat_proc$Notreported==0 & dat_proc$Unknown==0] <- 0
#
#
## nonURM=1 IF race is White AND ethnicity is not Hispanic
#dat_proc$nonURM <- NA
#dat_proc$nonURM <-
#  ifelse(dat_proc$race %in% c("White","Asian","Other","Multiracial") &
#    dat_proc$ethnicity == "Not Hispanic or Latino", 1,
#  dat_proc$nonURM
#  )
## nonURM=0 IF race is not "white or unknown" OR ethnicity is Hispanic
#dat_proc$nonURM <-
#  ifelse(!dat_proc$race %in% c("White","Asian","Other","Multiracial","Not reported and unknown") |
#    dat_proc$ethnicity == "Hispanic or Latino", 0,
#    dat_proc$nonURM
#  )
#dat_proc$URM.2 = 1-dat_proc$nonURM
#
#with(dat_proc, table(URMforsubcohortsampling, URM.2, useNA="ifany"))



###############################################################################
# stratum variables
# The code for Bstratum is trial specifc
# The code for tps.stratum and Wstratum are not trial specific since they are constructed on top of Bstratum
###############################################################################

# Bstratum: randomization strata
# Moderna: 1 ~ 3, defines the 3 baseline strata within trt/serostatus
if (study_name_code=="COVE") {
    dat_proc$Bstratum = with(dat_proc, ifelse(Senior, 1, ifelse(HighRiskInd == 1, 2, 3)))
    
} else if (study_name_code=="ENSEMBLE") {
    dat_proc$Bstratum =  with(dat_proc, strtoi(paste0(Senior, HighRiskInd), base = 2)) + 1

}

names(Bstratum.labels) <- Bstratum.labels

#with(dat_proc, table(Bstratum, Senior, HighRiskInd))


# demo.stratum: correlates sampling strata
# Moderna: 1 ~ 6 defines the 6 baseline strata within trt/serostatus
# may have NA b/c URMforsubcohortsampling may be NA
if (study_name_code=="COVE") {
    dat_proc$demo.stratum = with(dat_proc, ifelse (URMforsubcohortsampling==1, ifelse(Senior, 1, ifelse(HighRiskInd == 1, 2, 3)), 3+ifelse(Senior, 1, ifelse(HighRiskInd == 1, 2, 3))))

} else if (study_name_code=="ENSEMBLE") {
    # first step, stratify by age and high risk
    dat_proc$demo.stratum =  with(dat_proc, strtoi(paste0(Senior, HighRiskInd), base = 2)) + 1
    # second step, stratify by country
    dat_proc$demo.stratum=with(dat_proc, ifelse(Region==0 & URMforsubcohortsampling==0, demo.stratum + 4, demo.stratum)) # US, non-URM
    dat_proc$demo.stratum[dat_proc$Region==1] = dat_proc$demo.stratum[dat_proc$Region==1] + 8 # Latin America
    dat_proc$demo.stratum[dat_proc$Region==2] = dat_proc$demo.stratum[dat_proc$Region==2] + 12 # Southern Africa
    # the above sequence ends up setting US URM=NA to NA
    
    assertthat::assert_that(
        all(!with(dat_proc, xor(is.na(demo.stratum),  Region==0 & is.na(URMforsubcohortsampling) ))),
        msg = "demo.stratum is na if and only if URM is NA and north america")
    
} else stop("unknown study_name_code")  
  
names(demo.stratum.labels) <- demo.stratum.labels


# tps stratum, 1 ~ 4*max(demo.stratum), used in tps regression
dat_proc <- dat_proc %>%
  mutate(
    tps.stratum = demo.stratum + strtoi(paste0(Trt, Bserostatus), base = 2) * length(demo.stratum.labels)
  )

# Wstratum, 1 ~ max(tps.stratum), max(tps.stratum)+1, ..., max(tps.stratum)+4. 
# Used to compute sampling weights. 
# Differs from tps stratum in that case is a separate stratum within each of the four groups defined by Trt and Bserostatus
# A case will have a Wstratum even if its tps.stratum is NA
# The case is defined using EventIndPrimaryD29

max.tps=max(dat_proc$tps.stratum,na.rm=T)
dat_proc$Wstratum = dat_proc$tps.stratum
dat_proc$Wstratum[with(dat_proc, EventIndPrimaryD29==1 & Trt==0 & Bserostatus==0)]=max.tps+1
dat_proc$Wstratum[with(dat_proc, EventIndPrimaryD29==1 & Trt==0 & Bserostatus==1)]=max.tps+2
dat_proc$Wstratum[with(dat_proc, EventIndPrimaryD29==1 & Trt==1 & Bserostatus==0)]=max.tps+3
dat_proc$Wstratum[with(dat_proc, EventIndPrimaryD29==1 & Trt==1 & Bserostatus==1)]=max.tps+4

#subset(dat_proc, Trt==1 & Bserostatus==1 & EventIndPrimaryD29 == 1)[1:3,]

with(dat_proc, table(tps.stratum))

# map tps.stratum to stratification variables
tps.stratums=sort(unique(dat_proc$tps.stratum)); names(tps.stratums)=tps.stratums
decode.tps.stratum=t(sapply(tps.stratums, function(i) unlist(subset(dat_proc, tps.stratum==i)[1,
    if (study_name_code=="COVE") c("Senior", "HighRiskInd", "URMforsubcohortsampling") else if (study_name_code=="ENSEMBLE") c("Senior", "HighRiskInd", "Region", "URMforsubcohortsampling")
])))


###############################################################################
# observation-level weights
###############################################################################

#Wstratum may have NA if any variables to form strata has NA


# initially TwophasesampInd just need to be in the case or subcohort and have the necessary markers
# after defining ph1.xx, we will update TwophasesampInd to be 0 outside ph1.xx

if (has57)
dat_proc <- dat_proc %>%
  mutate(
    TwophasesampIndD57 =
      (SubcohortInd | EventIndPrimaryD29 == 1) &
      complete.cases(cbind(
        if("bindSpike" %in% must_have_assays) BbindSpike,
        if("bindRBD" %in% must_have_assays) BbindRBD,
        if("pseudoneutid50" %in% must_have_assays) Bpseudoneutid50,
        if("pseudoneutid80" %in% must_have_assays) Bpseudoneutid80,

        if("bindSpike" %in% must_have_assays) Day57bindSpike,
        if("bindRBD" %in% must_have_assays) Day57bindRBD,
        if("pseudoneutid50" %in% must_have_assays) Day57pseudoneutid50,
        if("pseudoneutid80" %in% must_have_assays) Day57pseudoneutid80,

        if("bindSpike" %in% must_have_assays & has29) Day29bindSpike,
        if("bindRBD" %in% must_have_assays & has29) Day29bindRBD,
        if("pseudoneutid50" %in% must_have_assays & has29) Day29pseudoneutid50,
        if("pseudoneutid80" %in% must_have_assays & has29) Day29pseudoneutid80
      ))
  )

if(has29) dat_proc <- dat_proc %>%
  mutate(
    TwophasesampIndD29 =
      (SubcohortInd | EventIndPrimaryD29 == 1) &
      complete.cases(cbind(
        if("bindSpike" %in% must_have_assays) BbindSpike, 
        if("bindRBD" %in% must_have_assays) BbindRBD, 
        if("pseudoneutid50" %in% must_have_assays) Bpseudoneutid50, 
        if("pseudoneutid80" %in% must_have_assays) Bpseudoneutid80, 
        
        if("bindSpike" %in% must_have_assays) Day29bindSpike,
        if("bindRBD" %in% must_have_assays) Day29bindRBD,
        if("pseudoneutid50" %in% must_have_assays) Day29pseudoneutid50, 
        if("pseudoneutid80" %in% must_have_assays) Day29pseudoneutid80
      ))
  )
  

# wt, for D57 correlates analyses
if (has57) {
    wts_table <- dat_proc %>% dplyr::filter(EarlyendpointD57==0 & Perprotocol==1 & EventTimePrimaryD57>=7) %>%
      with(table(Wstratum, TwophasesampIndD57))
    wts_norm <- rowSums(wts_table) / wts_table[, 2]
    dat_proc$wt.D57 <- wts_norm[dat_proc$Wstratum %.% ""]
    # the step above assigns weights for some subjects outside ph1. the next step makes them NA
    dat_proc$wt.D57 = ifelse(with(dat_proc, EarlyendpointD57==0 & Perprotocol==1 & EventTimePrimaryD57>=7), dat_proc$wt.D57, NA) 
    dat_proc$ph1.D57=!is.na(dat_proc$wt.D57)
    dat_proc$ph2.D57=with(dat_proc, ph1.D57 & TwophasesampIndD57)
    
    assertthat::assert_that(
        all(!is.na(subset(dat_proc, EarlyendpointD57==0 & Perprotocol==1 & EventTimePrimaryD57>=7 & !is.na(Wstratum), select=wt.D57, drop=T))),
        msg = "missing wt.D57 for D57 analyses ph1 subjects")
}

if(has29) {
    wts_table2 <- dat_proc %>% dplyr::filter(EarlyendpointD29==0 & Perprotocol==1 & EventTimePrimaryD29>=7) %>%
      with(table(Wstratum, TwophasesampIndD29))
    wts_norm2 <- rowSums(wts_table2) / wts_table2[, 2]
    dat_proc$wt.D29 <- wts_norm2[dat_proc$Wstratum %.% ""]
    dat_proc$wt.D29 = ifelse(with(dat_proc, EarlyendpointD29==0 & Perprotocol==1 & EventTimePrimaryD29>=7), dat_proc$wt.D29, NA)
    dat_proc$ph1.D29=!is.na(dat_proc$wt.D29)
    dat_proc$ph2.D29=with(dat_proc, ph1.D29 & TwophasesampIndD29)

    assertthat::assert_that(
        all(!is.na(subset(dat_proc, EarlyendpointD29==0 & Perprotocol==1 & EventTimePrimaryD29>=7 & !is.na(Wstratum), select=wt.D29, drop=T))),
        msg = "missing wt.D29 for D29 analyses ph1 subjects")
}

# define weights for intercurrent cases
if(has29 & has57) {
    wts_table2 <- dat_proc %>%               dplyr::filter(EarlyendpointD29==0 & Perprotocol==1 & EventIndPrimaryD29==1 & EventTimePrimaryD29>=7 & EventTimePrimaryD29 <= 6 + NumberdaysD1toD57 - NumberdaysD1toD29) %>%
      with(table(Wstratum, TwophasesampIndD29))
    wts_norm2 <- rowSums(wts_table2) / wts_table2[, 2]
    dat_proc$wt.intercurrent.cases <- wts_norm2[dat_proc$Wstratum %.% ""]
    dat_proc$wt.intercurrent.cases = ifelse(with(dat_proc, EarlyendpointD29==0 & Perprotocol==1 & EventIndPrimaryD29==1 & EventTimePrimaryD29>=7 & EventTimePrimaryD29 <= 6 + NumberdaysD1toD57 - NumberdaysD1toD29), 
                                            dat_proc$wt.intercurrent.cases, 
                                            NA)
    dat_proc$ph1.intercurrent.cases=!is.na(dat_proc$wt.intercurrent.cases)
    dat_proc$ph2.intercurrent.cases=with(dat_proc, ph1.intercurrent.cases & TwophasesampIndD29)    

    assertthat::assert_that(
        all(!is.na(subset(dat_proc,                        EarlyendpointD29==0 & Perprotocol==1 & EventIndPrimaryD29==1 & EventTimePrimaryD29>=7 & EventTimePrimaryD29 <= 6 + NumberdaysD1toD57 - NumberdaysD1toD29 & !is.na(Wstratum), select=wt.intercurrent.cases, drop=T))),
        msg = "missing wt.intercurrent.cases for intercurrent analyses ph1 subjects")
}

# wt.subcohort, for immunogenicity analyses that use subcohort only and are not enriched by cases outside subcohort
if (study_name_code=="COVE") {
    wts_table <- dat_proc %>%       dplyr::filter(EarlyendpointD57==0 & Perprotocol==1) %>%
      with(table(tps.stratum, TwophasesampIndD57 & SubcohortInd))
    wts_norm <- rowSums(wts_table) / wts_table[, 2]
    dat_proc$wt.subcohort <- wts_norm[dat_proc$tps.stratum %.% ""]
    dat_proc$wt.subcohort = ifelse(with(dat_proc, EarlyendpointD57==0 & Perprotocol==1), dat_proc$wt.subcohort, NA)
    dat_proc$ph1.immuno=!is.na(dat_proc$wt.subcohort)
    dat_proc$ph2.immuno=with(dat_proc, ph1.immuno & SubcohortInd & TwophasesampIndD57)
    
    assertthat::assert_that(
        all(!is.na(subset(dat_proc, EarlyendpointD57==0 & Perprotocol==1 & !is.na(tps.stratum), select=wt.subcohort, drop=T))), 
        msg = "missing wt.subcohort for immuno analyses ph1 subjects")
        
} else if (study_name_code=="ENSEMBLE") {
    wts_table <- dat_proc %>%       dplyr::filter(EarlyendpointD29==0 & Perprotocol==1) %>%
      with(table(tps.stratum, TwophasesampIndD29 & SubcohortInd))
    wts_norm <- rowSums(wts_table) / wts_table[, 2]
    dat_proc$wt.subcohort <- wts_norm[dat_proc$tps.stratum %.% ""]
    dat_proc$wt.subcohort = ifelse(with(dat_proc, EarlyendpointD29==0 & Perprotocol == 1), dat_proc$wt.subcohort, NA)
    dat_proc$ph1.immuno=!is.na(dat_proc$wt.subcohort)
    dat_proc$ph2.immuno=with(dat_proc, ph1.immuno & SubcohortInd & TwophasesampIndD29)
    
    assertthat::assert_that(
        all(!is.na(subset(dat_proc, EarlyendpointD29==0 & Perprotocol==1 & !is.na(tps.stratum), select=wt.subcohort, drop=T))), 
        msg = "missing wt.subcohort for immuno analyses ph1 subjects")
        
} else stop("unknown study_name_code")


# the following should not be defined because TwophasesampIndD57 and TwophasesampIndD29 are not ph2
#dat_proc$TwophasesampIndD57[!dat_proc$ph1.D57] <- 0
#if(has29) {
#dat_proc$TwophasesampIndD29[!dat_proc$ph1.D29] <- 0
#}






###############################################################################
# impute missing neut biomarkers in ph2
#     impute vaccine and placebo, baseline pos and neg, separately
#     use all assays (not bindN)
#     use baseline, D29 and D57, but not Delta
###############################################################################

if (has57) {    
    n.imp <- 1
    dat.tmp.impute <- subset(dat_proc, TwophasesampIndD57 == 1)
    
    imp.markers=c(outer(c("B", if(has29) "Day29", "Day57"), assays, "%.%"))
    
    for (trt in unique(dat_proc$Trt)) {
    for (sero in unique(dat_proc$Bserostatus)) {
    
      #summary(subset(dat.tmp.impute, Trt == 1 & Bserostatus==0)[imp.markers])
      
      imp <- dat.tmp.impute %>%
        dplyr::filter(Trt == trt & Bserostatus==sero) %>%
        select(all_of(imp.markers)) 
        
      # deal with constant variables
      for (a in names(imp)) {
        if (all(imp[[a]]==min(imp[[a]], na.rm=TRUE), na.rm=TRUE)) imp[[a]]=min(imp[[a]], na.rm=TRUE)
      }
        
      # diagnostics = FALSE , remove_collinear=F are needed to avoid errors due to collinearity
      imp <- imp %>%
        mice(m = n.imp, printFlag = FALSE, seed=1, diagnostics = FALSE , remove_collinear = FALSE)
        
      dat.tmp.impute[dat.tmp.impute$Trt == trt & dat.tmp.impute$Bserostatus == sero , imp.markers] <-
        mice::complete(imp, action = 1)
        
    }
    }
    
    # missing markers imputed properly?
    assertthat::assert_that(
        all(complete.cases(dat.tmp.impute[, imp.markers])),
        msg = "missing markers imputed properly?"
    )    
    
    # populate dat_proc imp.markers with the imputed values
    dat_proc[dat_proc$TwophasesampIndD57==1, imp.markers] <-
      dat.tmp.impute[imp.markers][match(dat_proc[dat_proc$TwophasesampIndD57==1, "Ptid"], dat.tmp.impute$Ptid), ]
    
    # imputed values of missing markers merged properly for all individuals in the two phase sample?
    assertthat::assert_that(
      all(complete.cases(dat_proc[dat_proc$TwophasesampIndD57 == 1, imp.markers])),
      msg = "imputed values of missing markers merged properly for all individuals in the two phase sample?"
    )
}

###############################################################################
# impute again for TwophasesampIndD29
#     use baseline and D29

if(has29) {
    n.imp <- 1
    dat.tmp.impute <- subset(dat_proc, TwophasesampIndD29 == 1)
    
    imp.markers=c(outer(c("B", "Day29"), assays, "%.%"))
    
    for (trt in unique(dat_proc$Trt)) {
    for (sero in unique(dat_proc$Bserostatus)) {
    
      #summary(subset(dat.tmp.impute, Trt == 1 & Bserostatus==0)[imp.markers])
        
      imp <- dat.tmp.impute %>%
        dplyr::filter(Trt == trt & Bserostatus==sero) %>%
        select(all_of(imp.markers)) 
      
      # deal with constant variables  
      for (a in names(imp)) {
        if (all(imp[[a]]==min(imp[[a]], na.rm=TRUE), na.rm=TRUE)) imp[[a]]=min(imp[[a]], na.rm=TRUE)
      }
      
      # diagnostics = FALSE , remove_collinear=F are needed to avoid errors due to collinearity
      imp <- imp %>%
        mice(m = n.imp, printFlag = FALSE, seed=1, diagnostics = FALSE , remove_collinear = FALSE)
        
      dat.tmp.impute[dat.tmp.impute$Trt == trt & dat.tmp.impute$Bserostatus == sero , imp.markers] <-
        mice::complete(imp, action = 1)
        
    }
    }
    
    # missing markers imputed properly?
    assertthat::assert_that(
        all(complete.cases(dat.tmp.impute[, imp.markers])),
        msg = "missing markers imputed properly for day 29?"
    ) 
    
    # populate dat_proc imp.markers with the imputed values
    dat_proc[dat_proc$TwophasesampIndD29==1, imp.markers] <-
      dat.tmp.impute[imp.markers][match(dat_proc[dat_proc$TwophasesampIndD29==1, "Ptid"], dat.tmp.impute$Ptid), ]    
}


assays.includeN=c(assays, "bindN")


###############################################################################
# converting binding variables from AU to IU for binding assays
###############################################################################

for (a in assays.includeN) {
  for (t in c("B", if(has29) "Day29", if(has57) "Day57") ) {
      dat_proc[[t %.% a]] <- dat_proc[[t %.% a]] + log10(convf[a])
  }
}


###############################################################################
# censoring values below LLOD
###############################################################################

# llod censoring
for (a in assays.includeN) {
  for (t in c("B", if(has29) "Day29", if(has57) "Day57") ) {
    dat_proc[[t %.% a]] <- ifelse(dat_proc[[t %.% a]] < log10(llods[a]), log10(llods[a] / 2), dat_proc[[t %.% a]])
  }
}

## uloq censoring for binding only
#for (a in c("bindSpike", "bindRBD", "bindN")) {
#  for (t in c("B", if(has29) "Day29", if(has57) "Day57") ) {
#    dat_proc[[t %.% a]] <- ifelse(dat_proc[[t %.% a]] > log10(uloqs[a]), log10(uloqs[a]    ), dat_proc[[t %.% a]])
#  }
#}



###############################################################################
# define delta for dat_proc
###############################################################################

tmp=list()
# lloq censoring
for (a in assays.includeN) {
  for (t in c("B", if(has29) "Day29", if(has57) "Day57") ) {
    tmp[[t %.% a]] <- ifelse(dat_proc[[t %.% a]] < log10(lloqs[a]), log10(lloqs[a] / 2), dat_proc[[t %.% a]])
  }
}
tmp=as.data.frame(tmp) # cannot subtract list from list, but can subtract data frame from data frame

if(has57)       dat_proc["Delta57overB"  %.% assays.includeN] <- tmp["Day57" %.% assays.includeN] - tmp["B"     %.% assays.includeN]
if(has29)       dat_proc["Delta29overB"  %.% assays.includeN] <- tmp["Day29" %.% assays.includeN] - tmp["B"     %.% assays.includeN]
if(has29&has57) dat_proc["Delta57over29" %.% assays.includeN] <- tmp["Day57" %.% assays.includeN] - tmp["Day29" %.% assays.includeN]



###############################################################################
# subset on subset_variable
###############################################################################

if(subset_value != "All"){
  include_in_subset <- dat_proc[[subset_variable]] == subset_value
  dat_proc <- dat_proc[include_in_subset, , drop = FALSE]
}


###############################################################################
# bundle data sets and save as CSV
###############################################################################

write_csv(dat_proc, file = here("data_clean", data_name))




###############################################################################
# save some common parameters and helper functions
###############################################################################

# maxed over Spike, RBD, N, restricting to Day 29 or 57
if(has29) MaxbAbDay29 = max(dat_proc[,paste0("Day29", c("bindSpike", "bindRBD", "bindN"))], na.rm=T)
if(has29) MaxbAbDelta29overB = max(dat_proc[,paste0("Delta29overB", c("bindSpike", "bindRBD", "bindN"))], na.rm=T)
if(has57) MaxbAbDay57 = max(dat_proc[,paste0("Day57", c("bindSpike", "bindRBD", "bindN"))], na.rm=T)
if(has57) MaxbAbDelta57overB = max(dat_proc[,paste0("Delta57overB", c("bindSpike", "bindRBD", "bindN"))], na.rm=T)

# maxed over ID50 and ID80, restricting to Day 29 or 57
if("pseudoneutid50" %in% assays & "pseudoneutid80" %in% assays) {
    if(has29) MaxID50ID80Day29 = max(dat_proc[,paste0("Day29", c("pseudoneutid50", "pseudoneutid80"))], na.rm=T)
    if(has29) MaxID50ID80Delta29overB = max(dat_proc[,paste0("Delta29overB", c("pseudoneutid50", "pseudoneutid80"))], na.rm=TRUE)
    if(has57) MaxID50ID80Day57 = max(dat_proc[,paste0("Day57", c("pseudoneutid50", "pseudoneutid80"))], na.rm=T)        
    if(has57) MaxID50ID80Delta57overB = max(dat_proc[,paste0("Delta57overB", c("pseudoneutid50", "pseudoneutid80"))], na.rm=TRUE)
}

save(list=c(if(has57) c("MaxbAbDay57", "MaxbAbDelta57overB", if("pseudoneutid50" %in% assays & "pseudoneutid80" %in% assays) c("MaxID50ID80Day57", "MaxID50ID80Delta57overB")), 
            if(has29) c("MaxbAbDay29", "MaxbAbDelta29overB", if("pseudoneutid50" %in% assays & "pseudoneutid80" %in% assays) c("MaxID50ID80Day29", "MaxID50ID80Delta29overB")),
            "decode.tps.stratum"
          ),
file=here("data_clean", paste0(attr(config, "config"), "_params.Rdata")))
