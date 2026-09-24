# ==============================================================================
# URBAN BIKE-SHARING DEMAND ANALYSIS
# Multiple Linear Regression and Regularisation
# ==============================================================================

# Objective:
# Investigate which weather, calendar, and temporal factors are associated
# with hourly bike-sharing demand.

# Dataset:
# UCI Machine Learning Repository - Bike Sharing Dataset
# Capital Bikeshare, Washington D.C. (2011-2012)

# Target variable:
# cnt = total number of bike rentals per hour


# 1. PACKAGES

library(tidyverse)

# 2. LOAD DATA 

DATA_PATH <- "data/hour.csv"

if (!file.exists(DATA_PATH)) {
  stop("Dataset not found. Expected file at: ", DATA_PATH)
}

bike_data <- read.csv(DATA_PATH)


# 3. INITIAL DATA VALIDATION

# Display dataset dimensions and structure
cat(
  "Dataset dimensions:",
  nrow(bike_data), "rows x",
  ncol(bike_data), "columns\n"
)

names(bike_data)
str(bike_data)
head(bike_data)
summary(bike_data)

required_columns <- c("dteday", "season", "yr", "mnth", "hr", "holiday",
                      "weekday", "workingday", "weathersit", "temp",
                      "atemp", "hum", "windspeed", "cnt")

if (any(bike_data$cnt < 0, na.rm = TRUE)) {
  stop("Target variable 'cnt' contains negative values.")
}

if (!all(required_columns %in% names(bike_data))) {
  stop("Dataset is missing one or more required columns.")
}

# Check data quality
missing_values <- sum(is.na(bike_data))
duplicate_rows <- sum(duplicated(bike_data))

cat("Missing values:", missing_values, "\n")
cat("Duplicate rows:", duplicate_rows, "\n")

# Stop the pipeline if unexpected data-quality issues are found
if (missing_values > 0) {
  stop("Dataset contains missing values. Review the data before modelling.")
}

if (duplicate_rows > 0) {
  stop("Dataset contains duplicate observations. Review the data before modelling.")
}

# 4. DATA PREPARATION

# Converting date from character to Date format
bike_data$dteday <- as.Date(bike_data$dteday)

# Converting categorical variables to factors
bike_data <- bike_data %>%
  mutate(
    season = factor(
      season,
      levels = c(1, 2, 3, 4),
      labels = c("Spring", "Summer", "Fall", "Winter")
    ),
    yr = factor(
      yr,
      levels = c(0, 1),
      labels = c("2011", "2012")
    ),
    mnth = factor(mnth),
    hr = factor(hr),
    holiday = factor(
      holiday,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    weekday = factor(
      weekday,
      levels = c(0, 1, 2, 3, 4, 5, 6),
      labels = c(
        "Sunday", "Monday","Tuesday","Wednesday","Thursday", "Friday","Saturday"
      )
    ),
    workingday = factor(
      workingday,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    weathersit = factor(
      weathersit,
      levels = c(1, 2, 3, 4),
      labels = c(
        "Clear","Mist_Cloudy","Light_Snow_Rain","Heavy_Rain_Snow"
      )
    ),
    weathersit = forcats::fct_collapse(
      weathersit,
      Rain_Snow = c("Light_Snow_Rain", "Heavy_Rain_Snow")
    )
  )

# Confirming the updated variable types
str(bike_data)

# Validate prepared variables
stopifnot(
  inherits(bike_data$dteday, "Date"),
  is.factor(bike_data$season),
  is.factor(bike_data$yr),
  is.factor(bike_data$mnth),
  is.factor(bike_data$hr),
  is.factor(bike_data$holiday),
  is.factor(bike_data$weekday),
  is.factor(bike_data$workingday),
  is.factor(bike_data$weathersit)
)

cat("Data preparation checks passed successfully.\n")

# 5. EXPLORATORY DATA ANALYSIS 

summary(bike_data$cnt)

# Standard deviation
sd(bike_data$cnt)

# Distribution of hourly bike rentals
demand_distribution_plot <- ggplot(bike_data, aes(x = cnt)) +
  geom_histogram(
    bins = 40,
    boundary = 0
  ) +
  theme_minimal() +
  labs(
    title = "Distribution of Hourly Bike-Sharing Demand",
    subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Number of Bike Rentals per Hour",
    y = "Frequency"
  )

print(demand_distribution_plot)

# Demand by hour of day
hourly_demand <- bike_data %>%
  group_by(hr) %>%
  summarise(
    mean_demand = mean(cnt),
    median_demand = median(cnt),
    .groups = "drop"
  )

print(hourly_demand)

hourly_demand_plot <- ggplot(
  hourly_demand,
  aes(x = as.numeric(as.character(hr)), y = mean_demand)
) +
  geom_line(linewidth = 1) +
  geom_point() +
  scale_x_continuous(breaks = 0:23) +
  theme_minimal() +
  labs(
    title = "Average Bike-Sharing Demand by Hour of Day",
    subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Hour of Day",
    y = "Average Number of Bike Rentals"
  )

print(hourly_demand_plot)

# Demand by hour and working-day status
hourly_workingday_demand <- bike_data %>%
  group_by(hr, workingday) %>%
  summarise(
    mean_demand = mean(cnt),
    .groups = "drop"
  )

hourly_workingday_plot <- ggplot(
  hourly_workingday_demand,
  aes(
    x = as.numeric(as.character(hr)),
    y = mean_demand,
    linetype = workingday,
    group = workingday
  )
) +
  geom_line(linewidth = 1) +
  geom_point() +
  scale_x_continuous(breaks = 0:23) +
  theme_minimal() +
  labs(
    title = "Hourly Bike Demand: Working vs Non-Working Days",
    subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Hour of Day",
    y = "Average Number of Bike Rentals",
    linetype = "Working Day"
  )

print(hourly_workingday_plot)

# Relationship between continuous weather variables and bike demand
weather_correlations <- bike_data %>%
  select(cnt, temp, atemp, hum, windspeed) %>%
  cor()

round(weather_correlations, 3)

# Temperature vs hourly demand
temperature_demand_plot <- ggplot(
  bike_data,
  aes(x = temp, y = cnt)
) +
  geom_point(alpha = 0.15) +
  geom_smooth(method = "loess", se = FALSE) +
  theme_minimal() +
  labs(
    title = "Bike-Sharing Demand and Temperature",
    subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Normalised Temperature",
    y = "Number of Bike Rentals per Hour"
  )

print(temperature_demand_plot)

# Demand by weather condition
weather_demand <- bike_data %>%
  group_by(weathersit) %>%
  summarise(observations = n(), mean_demand = mean(cnt),median_demand = median(cnt),.groups = "drop")

print(weather_demand)

weather_demand_plot <- ggplot(bike_data, aes(x = weathersit, y = cnt)) + geom_boxplot() +
  theme_minimal() +labs(title = "Bike-Sharing Demand by Weather Condition",
                        subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
                        x = "Weather Condition",y = "Number of Bike Rentals per Hour")

print(weather_demand_plot)

# Demand by season
season_demand <- bike_data %>%
  group_by(season) %>%
  summarise(observations = n(),mean_demand = mean(cnt), median_demand = median(cnt),.groups = "drop")

print(season_demand)

season_demand_plot <- ggplot(bike_data,aes(x = season, y = cnt)) +geom_boxplot() +theme_minimal() +
  labs(title = "Bike-Sharing Demand by Season",subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
       x = "Season", y = "Number of Bike Rentals per Hour")

print(season_demand_plot)

# Demand by year
year_demand <- bike_data %>%
  group_by(yr) %>%
  summarise(observations = n(),mean_demand = mean(cnt),median_demand = median(cnt),.groups = "drop")

print(year_demand)

year_demand_plot <- ggplot(bike_data,aes(x = yr, y = cnt)) + geom_boxplot() +theme_minimal() +
  labs(title = "Bike-Sharing Demand by Year",subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Year",y = "Number of Bike Rentals per Hour")

print(year_demand_plot)

# Demand by day of week
weekday_demand <- bike_data %>%
  group_by(weekday) %>%
  summarise(observations = n(),mean_demand = mean(cnt),median_demand = median(cnt),.groups = "drop")

print(weekday_demand)

weekday_demand_plot <- ggplot(bike_data,aes(x = weekday, y = cnt)) +geom_boxplot() +theme_minimal() +
  labs(title = "Bike-Sharing Demand by Day of Week",subtitle = "Capital Bikeshare, Washington D.C. (2011-2012)",
    x = "Day of Week",y = "Number of Bike Rentals per Hour")

print(weekday_demand_plot)

# Demand by month
month_demand <- bike_data %>%
  group_by(mnth) %>%
  summarise(observations = n(),mean_demand = mean(cnt),median_demand = median(cnt),.groups = "drop")

print(month_demand)

month_demand_plot <- ggplot(month_demand,aes(x = as.numeric(as.character(mnth)),
                                             y = mean_demand,group = 1)) +
  geom_line(linewidth = 1) + geom_point() + scale_x_continuous(breaks = 1:12,labels = month.abb) +
  theme_minimal() +labs(title = "Average Bike-Sharing Demand by Month",subtitle = "Capital Bikeshare,
                        Washington D.C. (2011-2012)",x = "Month",y = "Average Number of Bike Rentals")

print(month_demand_plot)

# Demand by holiday status
holiday_demand <- bike_data %>%
  group_by(holiday) %>%
  summarise(observations = n(),mean_demand = mean(cnt),median_demand = median(cnt),.groups = "drop")

print(holiday_demand)

holiday_demand_plot <- ggplot(bike_data,aes(x = holiday, y = cnt)) +geom_boxplot() +theme_minimal() +
  labs(title = "Bike-Sharing Demand on Holidays vs Non-Holidays",subtitle = "Capital Bikeshare, 
       Washington D.C. (2011-2012)",x = "Holiday",y = "Number of Bike Rentals per Hour")

print(holiday_demand_plot)

# 6. MODELLING DATA PREPARATION

# Excluded 'atemp' from modelling because it overlaps strongly with 'temp',
# avoiding redundant temperature predictors in the regression models.

# Excluded 'season' because monthly indicators already capture seasonal timing.

# Excluded 'weekday' because the model uses working-day and holiday indicators
# to represent the main calendar distinction of interest.

model_data <- bike_data %>%
  select(cnt,yr,mnth,hr,holiday,workingday,weathersit,temp,hum,windspeed)

# Inspect modelling dataset
dim(model_data)
str(model_data)
summary(model_data)

# Confirm no missing values
sum(is.na(model_data))

# 7. TRAIN / TEST SPLIT

# Set seed so the split is reproducible
RANDOM_SEED <- 42
set.seed(RANDOM_SEED)

# The dataset was randomly split observations into 80% training and 20% test sets.
# This evaluates generalisation to held-out observations within the
# observed 2011-2012 period, rather than future time-series forecasting.
train_index <- sample(
  seq_len(nrow(model_data)),
  size = floor(0.80 * nrow(model_data))
)

train_data <- model_data[train_index, ]
test_data  <- model_data[-train_index, ]

stopifnot(
  nrow(train_data) + nrow(test_data) == nrow(model_data),
  length(unique(train_index)) == length(train_index)
)

# Check split dimensions
dim(train_data)
dim(test_data)

# Check proportion of observations
round(nrow(train_data) / nrow(model_data), 3)
round(nrow(test_data) / nrow(model_data), 3)

# Reusable function for regression performance metrics
calculate_regression_metrics <- function(actual, predicted) {
  
  stopifnot(length(actual) == length(predicted))
  
  stopifnot(
    all(is.finite(actual)),
    all(is.finite(predicted))
  )
  
  stopifnot(var(actual) > 0)
  
  rmse <- sqrt(mean((actual - predicted)^2))
  mae <- mean(abs(actual - predicted))
  r2 <- 1 - (
    sum((actual - predicted)^2) /
      sum((actual - mean(actual))^2)
  )
  
  return(c(RMSE = rmse, MAE = mae, R2 = r2))
}

# 8. BASELINE MODEL

# Predict the mean training-set demand for every test observation
baseline_prediction <- mean(train_data$cnt)

baseline_predictions <- rep(
  baseline_prediction,
  nrow(test_data)
)

# Calculate baseline performance
baseline_metrics <- calculate_regression_metrics(
  actual = test_data$cnt,
  predicted = baseline_predictions
)

baseline_rmse <- baseline_metrics["RMSE"]
baseline_mae <- baseline_metrics["MAE"]
baseline_r2 <- baseline_metrics["R2"]

# Display results
cat("Baseline prediction:", round(baseline_prediction, 3), "\n")
cat("Baseline RMSE:", round(baseline_rmse, 3), "\n")
cat("Baseline MAE:", round(baseline_mae, 3), "\n")
cat("Baseline R-squared:", round(baseline_r2, 3), "\n")

# 9. FULL MULTIPLE LINEAR REGRESSION MODEL

# Define the common regression formula
model_formula <- cnt ~ yr + mnth + hr + holiday + workingday +
  weathersit + temp + hum + windspeed

full_mlr <- lm(model_formula, data = train_data
)

# Display model results
summary(full_mlr)

# 10. FULL MLR TEST-SET EVALUATION

# Generate predictions for unseen test data
full_mlr_predictions <- predict(full_mlr, newdata = test_data
)

# Calculate test-set performance
full_mlr_metrics <- calculate_regression_metrics(actual = test_data$cnt,
                                                 predicted = full_mlr_predictions)

full_mlr_rmse <- full_mlr_metrics["RMSE"]
full_mlr_mae <- full_mlr_metrics["MAE"]
full_mlr_r2 <- full_mlr_metrics["R2"]

# Display test-set performance
cat("Full MLR Test RMSE:", round(full_mlr_rmse, 3), "\n")
cat("Full MLR Test MAE:", round(full_mlr_mae, 3), "\n")
cat("Full MLR Test R-squared:", round(full_mlr_r2, 3), "\n")

# Calculate percentage improvement in RMSE over the mean baseline
full_mlr_improvement <- ((baseline_rmse - full_mlr_rmse) / baseline_rmse) * 100

cat("Full MLR RMSE improvement over mean baseline:",round(full_mlr_improvement, 2),"%\n")

# 11. REGRESSION DIAGNOSTICS

par(mfrow = c(2, 2))
plot(full_mlr)
par(mfrow = c(1, 1))

# Diagnostic plots indicate some nonlinearity, non-constant residual variance,
# and departures from normality. The Full MLR is therefore treated as an
# interpretable benchmark rather than a model with perfectly satisfied assumptions.

# 12. MULTICOLLINEARITY CHECK

vif_results <- car::vif(full_mlr)

print(vif_results)

# 13. STEPWISE MODEL SELECTION

# Perform backward stepwise selection using AIC
stepwise_mlr <- MASS::stepAIC(full_mlr,direction = "backward",trace = FALSE)

summary(stepwise_mlr)
formula(stepwise_mlr)

# Backward AIC retained all predictors from the full MLR,
# so the stepwise and full models have the same specification.

# 14. STEPWISE MODEL TEST-SET PERFORMANCE

stepwise_predictions <- predict(stepwise_mlr, newdata = test_data)

# Calculate test-set performance
stepwise_metrics <- calculate_regression_metrics(actual = test_data$cnt,
                                                 predicted = stepwise_predictions)

stepwise_rmse <- stepwise_metrics["RMSE"]
stepwise_mae <- stepwise_metrics["MAE"]
stepwise_r2 <- stepwise_metrics["R2"]

cat("Stepwise MLR Test RMSE:", round(stepwise_rmse, 3), "\n")
cat("Stepwise MLR Test MAE:", round(stepwise_mae, 3), "\n")
cat("Stepwise MLR Test R-squared:", round(stepwise_r2, 3), "\n")

# 15. LASSO REGRESSION

# Creating model matrices for glmnet
x_train <- model.matrix(model_formula,data = train_data)[, -1]

x_test <- model.matrix(model_formula,data = test_data)[, -1]

y_train <- train_data$cnt
y_test <- test_data$cnt

# Reset the seed to make cross-validation fold assignment reproducible
set.seed(RANDOM_SEED)

lasso_cv <- glmnet::cv.glmnet(x = x_train,y = y_train,alpha = 1,nfolds = 10)

best_lambda <- lasso_cv$lambda.min

cat("Best LASSO lambda:", best_lambda, "\n")

# Extract coefficients at the best cross-validated lambda
lasso_coefficients <- coef(lasso_cv,s = "lambda.min")

# Count non-zero LASSO predictor coefficients, excluding the intercept
lasso_nonzero_count <- sum(as.vector(lasso_coefficients[-1, ]) != 0)

cat("Non-zero LASSO predictor coefficients:",lasso_nonzero_count,"\n")

# At lambda.min, LASSO retained all 42 encoded predictor coefficients.

# A more regularised lambda.1se solution was also examined separately,
# but its small reduction in model complexity came with slightly worse
# held-out test performance, so lambda.min is retained for comparison.

# 16. LASSO TEST-SET PERFORMANCE

# Generate predictions using the best lambda
lasso_predictions <- predict(lasso_cv,newx = x_test,s = "lambda.min")

# Convert predictions to a numeric vector
lasso_predictions <- as.numeric(lasso_predictions)

# Calculate test-set performance
lasso_metrics <- calculate_regression_metrics(actual = y_test,predicted = lasso_predictions)

lasso_rmse <- lasso_metrics["RMSE"]
lasso_mae <- lasso_metrics["MAE"]
lasso_r2 <- lasso_metrics["R2"]

# Display test-set performance
cat("LASSO Test RMSE:", round(lasso_rmse, 3), "\n")
cat("LASSO Test MAE:", round(lasso_mae, 3), "\n")
cat("LASSO Test R-squared:", round(lasso_r2, 3), "\n")

# 17. MODEL PERFORMANCE COMPARISON

# Create comparison table
model_comparison <- data.frame(Model = c("Mean Baseline","Full MLR","Stepwise MLR","LASSO"),
  RMSE = c(baseline_rmse,full_mlr_rmse,stepwise_rmse,lasso_rmse),
  MAE = c(baseline_mae,full_mlr_mae,stepwise_mae,lasso_mae),
  R2 = c(baseline_r2,full_mlr_r2,stepwise_r2,lasso_r2))

model_comparison_full <- model_comparison

# Round metrics for readability
model_rmse_unrounded <- model_comparison$RMSE

model_comparison$RMSE <- round(model_comparison$RMSE, 3)
model_comparison$MAE <- round(model_comparison$MAE, 3)
model_comparison$R2 <- round(model_comparison$R2, 3)

# Display comparison
print(model_comparison)

# Identify model with lowest test RMSE
best_model <- model_comparison$Model[which.min(model_rmse_unrounded)]

cat("Lowest test-set RMSE:", best_model, "\n")

# 18. MODEL PERFORMANCE VISUALISATION

model_comparison_plot <- ggplot(model_comparison,aes(x = reorder(Model, RMSE),y = RMSE)) +
  geom_col() + coord_flip() +theme_minimal() +
  labs(title = "Test-Set Model Performance",
    subtitle = "Comparison of prediction error using RMSE",x = "Model",y = "RMSE")

print(model_comparison_plot)

# 19. ACTUAL VS PREDICTED VALUES

# Visualising Full MLR predictions as the main interpretable regression benchmark.
# Its test performance was effectively tied with the other regression approaches.
actual_vs_predicted <- data.frame(Actual = test_data$cnt, Predicted = full_mlr_predictions)

actual_vs_predicted_plot <- ggplot(actual_vs_predicted,aes(x = Actual, y = Predicted)) +
  geom_point(alpha = 0.35) +geom_abline(intercept = 0,slope = 1,linetype = "dashed") +
  theme_minimal() +labs(title = "Actual vs Predicted Bike-Sharing Demand",
    subtitle = "Full Multiple Linear Regression on the held-out test set",
    x = "Actual Bike Rentals per Hour",
    y = "Predicted Bike Rentals per Hour"
  )

print(actual_vs_predicted_plot)

# 20. SAVE PROJECT OUTPUTS

dir.create(
  "outputs/figures",
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  "outputs/tables",
  recursive = TRUE,
  showWarnings = FALSE
)

# Save Full MLR diagnostic plots
png(
  "outputs/figures/full_mlr_diagnostics.png",
  width = 1800,
  height = 1800,
  res = 200
)

par(mfrow = c(2, 2))
plot(full_mlr)
par(mfrow = c(1, 1))

dev.off()

# Save model comparison table
write.csv(
  model_comparison_full,
  "outputs/tables/model_comparison.csv",
  row.names = FALSE
)

# Save Full MLR coefficient estimates
full_mlr_coefficients <- as.data.frame(
  coef(summary(full_mlr))
)

full_mlr_coefficients$Term <- rownames(full_mlr_coefficients)
rownames(full_mlr_coefficients) <- NULL

write.csv(
  full_mlr_coefficients,
  "outputs/tables/full_mlr_coefficients.csv",
  row.names = FALSE
)

# Save multicollinearity diagnostics
vif_output <- as.data.frame(vif_results)
vif_output$Predictor <- rownames(vif_output)
rownames(vif_output) <- NULL

write.csv(
  vif_output,
  "outputs/tables/vif_results.csv",
  row.names = FALSE
)

# Save LASSO coefficient estimates
lasso_coefficients_output <- data.frame(
  Term = rownames(lasso_coefficients),
  Coefficient = as.numeric(lasso_coefficients)
)

write.csv(
  lasso_coefficients_output,
  "outputs/tables/lasso_coefficients.csv",
  row.names = FALSE
)

# Save LASSO cross-validation plot
png(
  "outputs/figures/lasso_cross_validation.png",
  width = 1800,
  height = 1200,
  res = 200
)

plot(lasso_cv)

dev.off()

# Save distribution of hourly bike demand
ggsave(
  "outputs/figures/demand_distribution.png",
  plot = demand_distribution_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save average demand by hour of day
ggsave(
  "outputs/figures/hourly_demand.png",
  plot = hourly_demand_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save hourly demand by working-day status plot
ggsave(
  "outputs/figures/hourly_workingday_demand.png",
  plot = hourly_workingday_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save temperature vs demand plot
ggsave(
  "outputs/figures/temperature_demand.png",
  plot = temperature_demand_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save demand by weather condition plot
ggsave(
  "outputs/figures/weather_demand.png",
  plot = weather_demand_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save model comparison plot
ggsave(
  "outputs/figures/model_comparison.png",
  plot = model_comparison_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Save actual vs predicted plot
ggsave(
  "outputs/figures/actual_vs_predicted.png",
  plot = actual_vs_predicted_plot,
  width = 8,
  height = 5,
  dpi = 300
)

cat("Project outputs saved successfully.\n")

# 21. REPRODUCIBILITY INFORMATION

# Save R and package version information
session_info <- capture.output(sessionInfo())

writeLines(
  session_info,
  "outputs/session_info.txt"
)

cat("Session information saved successfully.\n")

# 22. FINAL ANALYSIS SUMMARY

cat("\n")
cat("========================================\n")
cat("BIKE-SHARING DEMAND ANALYSIS SUMMARY\n")
cat("========================================\n")
cat("Training observations:", nrow(train_data), "\n")
cat("Test observations:", nrow(test_data), "\n")
cat("Mean baseline RMSE:", round(baseline_rmse, 3), "\n")
cat("Full MLR RMSE:", round(full_mlr_rmse, 3), "\n")
cat("Stepwise MLR RMSE:", round(stepwise_rmse, 3), "\n")
cat("LASSO RMSE:", round(lasso_rmse, 3), "\n")
cat("Full MLR test R-squared:", round(full_mlr_r2, 3), "\n")
cat("Lowest test-set RMSE model:", best_model, "\n")
cat(
  "RMSE improvement over mean baseline:",
  round(full_mlr_improvement, 2),
  "%\n"
)
cat("========================================\n")