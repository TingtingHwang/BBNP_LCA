import scipy.io as scio
from scipy.io import savemat  # Save a dictionary as a .mat file
import numpy as np
from sklearn.metrics import r2_score
import lightgbm as lgb
import shap
import matplotlib.pyplot as plt
import pandas as pd

# Load data
data_train = scio.loadmat('./data/Train_data_SOFM.mat')  # Modify the .mat filename exported from MATLAB

# Training set input and output
data_train_x = data_train['Train_data_x']
data_train_y = data_train['Train_data_y']

# Standardization using Z-score normalization
X_mean, y_mean = data_train_x.mean(0), data_train_y.mean(0)
X_std, y_std = data_train_x.std(0), data_train_y.std(0)

data_train_x_nor = (data_train_x - X_mean) / X_std
data_train_y_nor = (data_train_y - y_mean) / y_std


# Define evaluation function
# Same as the five metrics in the toolbox
def evaluate_regress(y_pre, y_true):
    MAE = np.sum(np.abs(y_pre - y_true)) / len(y_true)
    print('MAE: ', str(MAE))

    MAPE = np.sum(np.abs((y_pre - y_true) / y_true)) / len(y_true)
    print('MAPE: ', str(MAPE))

    MSE = np.sum((y_pre - y_true) ** 2) / len(y_true)
    print('MSE: ', str(MSE))

    RMSE = np.sqrt(MSE)
    print('RMSE: ', str(RMSE))

    R2 = r2_score(y_true, y_pre)
    print('R2: ', str(R2))

    return MAE, MAPE, MSE, RMSE, R2


# MAE, MAPE, MSE, RMSE, R2 = evaluate_regress(data_test_prey, data_test_y)

# Detailed tutorial on LightGBM:
# https://jmarkhou.com/lgbqr/

quantile = 0.5  # Median

model_lgb = lgb.train({'objective': 'quantile', 'alpha': quantile, 'force_col_wise': True},
                       lgb.Dataset(data_train_x_nor, data_train_y_nor), num_boost_round=200)

y_pred_train_nor = model_lgb.predict(data_train_x_nor)

y_pred_train = y_pred_train_nor * y_std + y_mean
y_pred_train1 = y_pred_train.reshape(len(y_pred_train), 1)

MAE, MAPE, MSE, RMSE, R2 = evaluate_regress(y_pred_train, y_pred_train1)

data_Oriny_pre = {}
data_Oriny_pre['y_train_predict'] = y_pred_train1

# savemat('Training results lightgbm_predict.mat', data_Oriny_pre)

# Create SHAP explainer
explainer = shap.TreeExplainer(model_lgb)

# Compute SHAP values
shap_values = explainer.shap_values(data_train_x_nor)

# Feature labels
feature_label = ['Altitude', 'Geology', 'Historic landscape', 'Landcover', 'Landform', 'Soilscape', 'Vegetation']

data_train_x_nor1 = pd.DataFrame(data_train_x_nor, columns=feature_label)


## Beeswarm plot
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = 'Times New Roman'
plt.rcParams['font.size'] = 14  # Set font size to 14

# Create SHAP visualization
# Color schemes: viridis, Spectral, coolwarm, RdYlGn, RdYlBu, RdBu, RdGy, PuOr, BrBG, PRGn, PiYG
shap.summary_plot(shap_values, data_train_x_nor, feature_names=feature_label, cmap='PRGn', show=False)

# Display interpretation:
# - Pink dots: indicate that the feature value positively impacts the model prediction (increases the prediction value).
# - Blue dots: indicate that the feature value negatively impacts the model prediction (decreases the prediction value).
# - The horizontal axis (SHAP values) shows the magnitude of the impact. The further a dot is from the center (zero point), the greater the feature's influence.
# - Features at the top have the highest impact on model output, while those at the bottom have a smaller impact.
# - The most influential feature (e.g., "lstat") has a mix of positive and negative effects, indicating a high variation in impact.
# - Middle-ranked features (e.g., "rm" and "dis") show more concentrated effects with moderate influence.
# - The least influential features (e.g., "chas" and "zn") contribute minimally to the model predictions.

# Save the figure as a high-quality image file
plt.savefig('./SOFM_beeswarm.png', dpi=800, bbox_inches='tight')


## Bar plot
# shap.summary_plot(shap_values, data_train_x_nor, feature_names=feature_label, plot_type='bar', color='lightblue', show=False)
# This shows the absolute importance values by averaging the absolute SHAP values.
# In a housing price prediction model, features like "lstat" (low-status population percentage) and "rm" (average number of rooms per dwelling) are likely key influencing factors.
# Save the figure as a high-quality image file
# plt.savefig('./picture_STSC_OPbar.png', dpi=300, bbox_inches='tight')
# plt.show()


## Dependence plot
# Set font to Times New Roman and adjust size
# plt.rcParams['font.family'] = 'serif'
# plt.rcParams['font.serif'] = 'Times New Roman'
# plt.rcParams['font.size'] = 12  # Set font size to 12

# Create SHAP dependence plot with color scheme 'RdBu'
# shap.dependence_plot('Feature 1', shap_values, data_train_x_nor, interaction_index='Feature 2')
# shap.dependence_plot('Historic', shap_values, data_train_x_nor1, interaction_index='Soilscape', cmap='PRGn', show=False)

# Save the figure as a high-quality image file
# plt.savefig('./picture_SOFM_interaction_two.png', dpi=300, bbox_inches='tight')

# Interpretation:
# - Negative correlation: lstat has a significant negative impact on predictions. Higher lstat values decrease the predicted values.
# - Degree of impact: lstat values between 0 and 2 show the most significant changes in SHAP values, indicating a strong influence.
# - Feature importance: This plot demonstrates that lstat is a crucial predictor. Understanding its influence helps optimize the model.
# - Model optimization: Dependence plots reveal sensitivity to specific feature ranges, aiding data collection and model tuning.


## Single-feature contribution plot
# Set font to Times New Roman and adjust size
# plt.rcParams['font.family'] = 'serif'
# plt.rcParams['font.serif'] = 'Times New Roman'
# plt.rcParams['font.size'] = 12  # Set font size to 12

# shap.dependence_plot('Geology', shap_values, data_train_x_nor1, interaction_index=None, cmap='PRGn', show=False)

# Save the figure as a high-quality image file
# plt.savefig('./SOFM_Geology_contribution1.png', dpi=300, bbox_inches='tight')


## Interaction plot
# shap_interaction_values = explainer.shap_interaction_values(data_train_x_nor1)
# shap.summary_plot(shap_interaction_values, data_train_x_nor1)

# plt.rcParams['font.family'] = 'serif'
# plt.rcParams['font.serif'] = 'Times New Roman'
# plt.rcParams['font.size'] = 12  # Set font size to 12

# Modify global color scheme
# plt.set_cmap('PRGn')  # Choose preferred color scheme

# Generate interaction plot
# shap.summary_plot(shap_interaction_values, data_train_x_nor1, plot_type='dot', cmap='PiYG')

# Adjust figure size
# plt.gcf().set_size_inches(7, 6)

# Save the figure as a high-quality image file
# plt.savefig('./MC_interaction.png', dpi=300, bbox_inches='tight')
