##Data Preprocessing

library(tidyverse)
loan <- read.csv("loan_train.csv")
head(loan)
# take a quick look at the data
str(loan)
# convert the MIS_Status to numeric values 0 or 1
loan$MIS_Status <- ifelse(loan$MIS_Status == "P I F", 1, 0)
# check for missing value
library(naniar)
miss_var_summary(loan)

## impute the missing values

# number of record for each level of LowDoc
loan %>%
  group_by(loan$RevLineCr) %>%
  tally()
# convert NA to a new category
loan$RevLineCr <- ifelse(loan$RevLineCr=="", "other", as.character(loan$RevLineCr))
loan <- loan %>%
  mutate(RevLineCr = replace(RevLineCr, is.na(RevLineCr), "other"))
# inpute NA of `DisbursementDate` and `xx` with the median
loan <- loan %>% 
  mutate(DisbursementDate = replace(DisbursementDate, is.na(DisbursementDate),
                                    round(median(DisbursementDate, na.rm = T))))
loan <- loan %>% 
  mutate(xx = replace(xx, is.na(xx), round(median(xx, na.rm = T))))
# check if any NA
any_na(loan) # No missing values now

# Check for factors if there are more levels than specified in description
unique(loan$NewExist) # ok
unique(loan$UrbanRural) # ok 
unique(loan$New) # ok
unique(loan$RealEstate) # ok
unique(loan$Recession) # ok
# it seems that `NewExist` and `New` are talking about the same thing
sum(loan$New=="0") == sum(loan$NewExist=="1") 

loan %>%
  group_by(loan$LowDoc) %>%
  tally()
# `LowDoc` has 2 more levels
# `RevLineCr` has 2 more levels
# so we combine the extra levels into one level
loan$LowDoc <- ifelse(loan$LowDoc=="0"|loan$LowDoc=="S", "other", as.character(loan$LowDoc))
loan$RevLineCr <- ifelse(loan$RevLineCr=="T"|loan$RevLineCr=="0", 
                         "other", as.character(loan$RevLineCr))
loan$FranchiseCode <-  ifelse(loan$FranchiseCode==0|loan$FranchiseCode==1, 0, loan$FranchiseCode)

# remove 
remove <- c("LoanNr_ChkDgt", "Name", "City", "Zip", "Bank", "NAICS")
loan <- loan[, -which(names(loan) %in% remove)]

# look at the data again and convert all characters to factors
str(loan)
loan$MIS_Status <- as.factor(loan$MIS_Status)
loan$RevLineCr <- as.factor(loan$RevLineCr)
loan$LowDoc <- as.factor(loan$LowDoc)
#loan$NAICS <- as.factor(loan$NAICS)

# process test data set
loan_test <- read.csv("loan_test.csv")
str(loan_test)
miss_var_summary(loan_test)
loan_test %>%
  group_by(loan_test$NewExist) %>%
  tally()
# inpute NA and 0 in NewExist with info from New
loan_test$NewExist[which(is.na(loan_test$NewExist))] <- loan_test$New[which(is.na(loan_test$NewExist))] + 1
loan_test$NewExist[which(loan_test$NewExist==0)] <- loan_test$New[which(loan_test$NewExist==0)] + 1
all(loan_test$NewExist == loan_test$New + 1)
# inpute NA of `DisbursementDate` and `xx` with the median
loan_test <- loan_test %>% 
  mutate(DisbursementDate = replace(DisbursementDate, is.na(DisbursementDate),
                                    round(median(DisbursementDate, na.rm = T))))
loan_test <- loan_test %>% 
  mutate(xx = replace(xx, is.na(xx), round(median(xx, na.rm = T))))
# check if any NA
any_na(loan_test)
# Check for factors if there are more levels than specified in description
unique(loan_test$NewExist) # ok
unique(loan_test$UrbanRural) # ok 
unique(loan_test$New) # ok
unique(loan_test$RealEstate) # ok
unique(loan_test$Recession) # ok
# process `BankState`, `LowDoc` and `RevLineCr` column
loan_test %>%
  group_by(BankState) %>%
  tally() # found missing value here
loan_test$BankState <- ifelse(loan_test$BankState=="", "other", as.character(loan_test$BankState))
loan_test$BankState <- ifelse(loan_test$BankState=="", "other", as.character(loan_test$BankState))
loan_test %>%
  group_by(LowDoc) %>%
  tally() # found NA here
loan_test$LowDoc <- ifelse(loan_test$LowDoc==""|loan_test$LowDoc=="A", "other", as.character(loan_test$LowDoc))
loan_test %>%
  group_by(RevLineCr) %>%
  tally()
loan_test$RevLineCr <- ifelse(loan_test$RevLineCr=="T"|loan_test$RevLineCr=="0", 
                              "other", as.character(loan_test$RevLineCr))
# remove columns
loan_test <- loan_test[, -which(names(loan_test) %in% remove)]
# convert characters to factors
loan_test$RevLineCr <- as.factor(loan_test$RevLineCr)
loan_test$LowDoc <- as.factor(loan_test$LowDoc)
loan_test$BankState <- as.factor(loan_test$BankState)
#loan_test$NAICS <- as.factor(loan_test$NAICS)
loan_test$FranchiseCode <-  ifelse(loan_test$FranchiseCode==0|loan_test$FranchiseCode==1, 0, loan_test$FranchiseCode)

total.loan <- rbind(loan[,-1], loan_test[,-1])
levels(loan$BankState) <- levels(total.loan$BankState)
levels(loan_test$BankState) <- levels(loan$BankState)

# split the data set
set.seed(1)
sample_size <- nrow(loan) * 0.8
train <- sample(1:nrow(loan), sample_size)
loan_train <- loan[train, ]
loan_valid <- loan[-train, ]

## Random Forest

set.seed(1)
library(randomForest)
loan.rf <- randomForest(MIS_Status ~ ., data = loan, subset = train, importance = TRUE, ntree = 100, mtry = 5) # since we have 24 predictors
pred.rf <- predict(loan.rf, loan_valid, type = "class")
table(pred.rf, loan_valid$MIS_Status)
accuracy <- mean(pred.rf == loan_valid$MIS_Status)
accuracy
# tune rf
loan.tuned <- tuneRF(x = loan_train[,-1], y = loan_train$MIS_Status, ntreeTry = 500, doBest = TRUE)
print(loan.tuned)
pred.tuning <- predict(loan.tuned, loan_valid, type = "class")
mean(pred.tuning == loan_valid$MIS_Status)

pred.rf.sub <- predict(loan.rf, loan_test[,-1], type = "class")
#write.table(pred.rf.sub, "prediction4.csv", row.names=FALSE)

pred.tune.sub <- predict(loan.tuned, loan_test[,-1], type = "class")
#write.table(pred.tune.sub, "prediction3.csv", row.names=FALSE)

## ROC curve
library(ROCR)
pred.list <- list(as.numeric(pred.rf), as.numeric(pred.tuning))
act.list <- rep(list(loan_valid$MIS_Status), length(pred.list))
pred <- prediction(pred.list, act.list)
roc <- performance(pred, "tpr", "fpr")
plot(roc, col = as.list(1:length(pred.list)))
abline(a = 0, b = 1, lty = "dashed")
legend(x = "bottomright", 
       legend = c("Random Forest", "tunning"),
       fill = 1:length(pred.list))
auc <- performance(pred, measure = "auc")
unlist(auc@y.values)

## Basic Neural Network
library(keras)

total.loan$State <-  as.numeric(total.loan$State)
total.loan$BankState <- to_categorical(as.numeric(total.loan$BankState))
total.loan$NewExist <-  total.loan$NewExist - 1
total.loan$UrbanRural <- to_categorical(total.loan$UrbanRural)
total.loan$RevLineCr <- to_categorical(as.numeric(total.loan$RevLineCr))
total.loan$LowDoc <- to_categorical(as.numeric(total.loan$LowDoc))
loan_encode <- cbind(loan[,1], total.loan[1:1102,])
loan_test_encode <- total.loan[1103:2102,]

# build normalize function
normal <- function(x) {
  num <- x - min(x)
  denom <- max(x) - min(x)
  return (num/denom)
}

# normalize data:
loan_encode$ApprovalDate <- normal(loan_encode$ApprovalDate)
loan_encode$ApprovalFY <- normal(loan_encode$ApprovalFY)
loan_encode$Term <- normal(loan_encode$Term)
loan_encode$NoEmp <- normal(loan_encode$NoEmp)
loan_encode$CreateJob <- normal(loan_encode$CreateJob)
loan_encode$RetainedJob <- normal(loan_encode$RetainedJob)
loan_encode$FranchiseCode <- normal(loan_encode$FranchiseCode)
loan_encode$DisbursementDate <- normal(loan_encode$DisbursementDate)
loan_encode$DisbursementGross <- normal(loan_encode$DisbursementGross)
loan_encode$GrAppv <- normal(loan_encode$GrAppv)
loan_encode$SBA_Appv <- normal(loan_encode$SBA_Appv)
loan_encode$daysterm <- normal(loan_encode$daysterm)
loan_encode$xx <- normal(loan_encode$xx)

loan_encode[,1] <- to_categorical(loan_encode[,1])
loan_encode <- as.matrix(loan_encode)
dimnames <- NULL

# split the data set
loan_train <- loan_encode[train, ]
loan_valid <- loan_encode[-train, ]

train_data <- loan_train[, -1:-2]
train_target <- loan_train[, 1:2]
test_data <- loan_valid[, -1:-2]
test_target <- loan_valid[, 1:2]

# design the architecture
network <- keras_model_sequential() %>%
  layer_dense(units = 128, activation = "relu", input_shape = c(ncol(train_data))) %>%
  layer_dropout(0.1) %>%
  layer_dense(units = 64, activation = "relu") %>%
  layer_dropout(0.1) %>%
  layer_dense(units = 2, activation = "softmax")

# compile network
network %>% compile(
  optimizer = optimizer_adam(lr=0.001, beta_1=0.9, beta_2=0.999, epsilon=NULL, decay=0.004),
  loss = "binary_crossentropy",
  metrics = c("accuracy")
)

# fit the model
history <- network %>% fit(
  train_data, 
  train_target, 
  epochs = 100, 
  batch_size = 50, 
  validation_split = 0.2)

# predict based on the test data
performance <- network %>% evaluate(test_data, test_target)
print(performance)

# prediction
pred.valid <- network %>% predict_classes(test_data)

# confusion matrix
table(pred.valid, test_target[,2])

# process test data
# normalize data:
loan_test_encode$ApprovalDate <- normal(loan_test_encode$ApprovalDate)
loan_test_encode$ApprovalFY <- normal(loan_test_encode$ApprovalFY)
loan_test_encode$Term <- normal(loan_test_encode$Term)
loan_test_encode$NoEmp <- normal(loan_test_encode$NoEmp)
loan_test_encode$CreateJob <- normal(loan_test_encode$CreateJob)
loan_test_encode$RetainedJob <- normal(loan_test_encode$RetainedJob)
loan_test_encode$FranchiseCode <- normal(loan_test_encode$FranchiseCode)
loan_test_encode$DisbursementDate <- normal(loan_test_encode$DisbursementDate)
loan_test_encode$DisbursementGross <- normal(loan_test_encode$DisbursementGross)
loan_test_encode$GrAppv <- normal(loan_test_encode$GrAppv)
loan_test_encode$SBA_Appv <- normal(loan_test_encode$SBA_Appv)
loan_test_encode$daysterm <- normal(loan_test_encode$daysterm)
loan_test_encode$xx <- normal(loan_test_encode$xx)

loan_test_encode <- as.matrix(loan_test_encode)
dimnames <- NULL

# prediction on test data
pred.nn <- network %>% predict_classes(loan_test_encode)
#write.table(pred.nn, "prediction.csv", row.names=FALSE)

summary(network)
