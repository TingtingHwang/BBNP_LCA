# 加载必要的包
# install.packages(c("vegan", "ecodist", "ggplot2"))
library(ecodist)
library(ggplot2)
library(permute)
library(lattice)
library(vegan)
#1. 数据准备
#将 X1 和 X2 转换为距离矩阵，假设它们存储在 X1_data.csv 和 X2_data.csv 文件中。

# 导入数据
X1 <- read.csv("D:/Code/R/BBNP/MRM/Data/SOFM_Element.csv", row.names = 1)   
X2 <- read.csv("D:/Code/R/BBNP/MRM/Data/SOFM_Frag2.csv", row.names = 1)# 


# dist_X1 和 dist_X2 必须是 dist 类型
# set.seed(123)
# X1 <- matrix(runif(100, 1, 100), nrow = 20)
# X2 <- matrix(runif(100, 1, 100), nrow = 20)

# 标准化矩阵（零均值和单位标准差）
# X1_scaled <- scale(X1)
# X2_scaled <- scale(X2)


# 计算距离矩阵（Bray-Curtis 距离）
# dist_X1 <- vegdist(X1_scaled, method = "bray")# Bray-Curtis 距离
# dist_X2 <- vegdist(X2_scaled, method = "euclidean")# 欧几里得距离

dist_X1 <- vegdist(X1, method = "bray")# Bray-Curtis 距离
dist_X2 <- vegdist(X2, method = "euclidean")# 欧几里得距离

# show(dist_X1)


#2. 检查数据
# 创建数据框
df <- data.frame(X1_dist = as.vector(dist_X1), X2_dist = as.vector(dist_X2))

# 绘制散点图
library(ggplot2)
ggplot(df, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "blue") +
  geom_smooth(method = "lm", col = "red") +
  labs(
    title = "Data Scatter Plot",
    x = "Distance Matrix X2",
    y = "Distance Matrix X1"
  ) +
  annotate(
    "text",
    x = max(df$X2_dist) * 0.8,
    y = max(df$X1_dist) * 0.9,
    label = paste0("r = ", round(0.2214, 3), ", p = 0.022"),
    color = "black",
    size = 5
  ) +
  theme_minimal()


#2.异常值处理
######数据异常值处理
# 计算 IQR（四分位间距）
iqr_X1 <- IQR(df$X1_dist)
iqr_X2 <- IQR(df$X2_dist)

# 定义上下限
#opmc的定义
# lower_bound_X1 <- quantile(df$X1_dist, 0.18) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.30) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.25) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

#STSC的定义
# lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.75) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.25) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

# lower_bound_X1 <- quantile(df$X1_dist, 0.35) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.55) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.25) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.55) + 1.5 * iqr_X2


#SOFM的定义
lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
upper_bound_X1 <- quantile(df$X1_dist, 0.55) + 1.5 * iqr_X1
lower_bound_X2 <- quantile(df$X2_dist, 0.1) - 1.5 * iqr_X2
upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

#EBMC的定义
# lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.75) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.15) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.25) + 1.5 * iqr_X2


# 标记异常值
df$outlier <- with(df, 
                   (X1_dist < lower_bound_X1 | X1_dist > upper_bound_X1) |
                     (X2_dist < lower_bound_X2 | X2_dist > upper_bound_X2))

#可视化标记异常值
library(ggplot2)
ggplot(df, aes(x = X2_dist, y = X1_dist, color = outlier)) +
  geom_point() +
  geom_smooth(method = "lm", col = "red") +
  scale_color_manual(values = c("FALSE" = "blue", "TRUE" = "orange")) +
  labs(title = "X1 vs X2 with Outliers Highlighted",
       x = "Distance Matrix X2",
       y = "Distance Matrix X1",
       color = "Outlier") +
  theme_minimal()

# 查看异常值
outliers <- df[df$outlier, ]
print(outliers)

# 移除异常值
df_clean <- df[!df$outlier, ]

# 重新拟合模型
model_clean <- lm(X1_dist ~ X2_dist, data = df_clean)

# 打印结果
summary(model_clean)

# 重新绘制散点图
library(ggplot2)
ggplot(df_clean, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "blue") +
  geom_smooth(method = "lm", col = "red") +
  labs(title = "Scatter Plot without Outliers",
       x = "Distance Matrix X2",
       y = "Distance Matrix X1") +
  theme_minimal()


# 替换异常值为中位数
df$X1_dist[df$outlier] <- median(df$X1_dist, na.rm = TRUE)
df$X2_dist[df$outlier] <- median(df$X2_dist, na.rm = TRUE)


# #重新生成原始数据矩阵
# 从替换后的 df 构建原始矩阵
n <- sqrt(2 * nrow(df) + 0.25) - 0.5  # 计算矩阵维度 n
matrix_X1 <- matrix(0, nrow = n, ncol = n)
matrix_X2 <- matrix(0, nrow = n, ncol = n)

# 填充矩阵的下三角
matrix_X1[lower.tri(matrix_X1)] <- df$X1_dist
matrix_X2[lower.tri(matrix_X2)] <- df$X2_dist

# 对称化矩阵
matrix_X1 <- matrix_X1 + t(matrix_X1)
matrix_X2 <- matrix_X2 + t(matrix_X2)

# 重新生成距离矩阵
dist_X1_clean <- as.dist(matrix_X1)
dist_X2_clean <- as.dist(matrix_X2)

# 绘制替换后的散点图
# ggplot(df, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "blue") +
#   geom_smooth(method = "lm", col = "red") +
#   labs(title = "Scatter Plot with Replaced Outliers",
#        x = "Distance Matrix X2",
#        y = "Distance Matrix X1") +
#   theme_minimal()




#3. Mantel 分析
# 安装并加载 vegan 包
#install.packages("vegan")
library(vegan)

# 使用 Mantel 检验
mantel_result <- vegan::mantel(dist_X1_clean, dist_X2_clean, permutations = 999, method = "spearman")#spearman
# mantel_result <- vegan::mantel(dist_X1, dist_X2, permutations = 999, method = "spearman")#spearman

# 打印结果
print(mantel_result)



#4. 多回归模型 (MRM)
# 安装并加载 ecodist 包
#install.packages("ecodist")
library(ecodist)

# 执行 MRM 分析
mrm_result <- MRM(dist_X1_clean ~ dist_X2_clean, nperm = 999)
# mrm_result <- MRM(dist_X1 ~ dist_X2, nperm = 999)

# 打印结果
print(mrm_result)


# 添加非线性项
# mrm_nonlinear <- MRM(dist_X1 ~ dist_X2 + I(dist_X2^2), nperm = 999)
# 打印结果
# print(mrm_nonlinear)



# 5.Mantel 可视化
#可视化
df_mantel <- data.frame(
  X1_dist = as.vector(as.matrix(dist_X1_clean)),
  X2_dist = as.vector(as.matrix(dist_X2_clean))
)

####删除最小值
# # 找到 X1_dist 的最小值
# min_X1 <- min(df_mantel$X1_dist)
# rows_to_remove <- which(df_mantel$X1_dist == min_X1)
# 
# # 如果需要同时考虑 X2_dist 的最小值
# # min_X2 <- min(df_mantel$X2_dist)
# # rows_to_remove <- unique(c(rows_to_remove, which(df_mantel$X2_dist == min_X2)))
# 
# # 删除对应的行
# df_mantel_clean <- df_mantel[-rows_to_remove, ]


# # 重新绘制散点图
# p_mantel_clean <- ggplot(df_mantel_clean, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   labs(
#     title = "Mantel Test Scatter Plot (Without Lowest Point)",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements",
#     caption = paste0("Mantel r = ", round(mantel_result$statistic, 3), ", p = ", mantel_result$signif)
#   ) +
#   theme_minimal()
# 
# print(p_mantel_clean)
# 
# # 调整 y 轴的下边界为 0，上边界为自动或自定义值
# p_mantel_clean <- ggplot(df_mantel_clean, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   scale_y_continuous(limits = c(0, NA)) +  # y 轴下边界为 0，上边界自动
#   labs(
#     title = "Mantel Test Scatter Plot (Without Lowest Point)",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements",
#     caption = paste0("Mantel r = ", round(mantel_result$statistic, 3), ", p = ", mantel_result$signif)
#   ) +
#   theme_minimal()
# 
# print(p_mantel_clean)


###绘图
# 未设置字体字号
# library(ggplot2)
# library(ggplot2)
# p_mantel <- ggplot(df_mantel_clean, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   labs(
#     title = "Mantel Test Scatter Plot (With Replaced Outliers)",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements",
#     caption = paste0("Mantel r = ", round(mantel_result$statistic, 3),", p = ", mantel_result$signif),
#     color = "black",
#     size = 5
#   ) +
#   theme_minimal()
# 
# print(p_mantel)

# 加载必要的库
library(ggplot2)
library(extrafont)  # 如果没有安装，可以运行 install.packages("extrafont")
# 确保字体 Times New Roman 可用
# loadfonts(device = "win")  # 如果您在 Windows 上运行

# 创建绘图
p_mantel <- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "black", alpha = 0.4) +
  geom_smooth(method = "lm", col = "black") +
  scale_y_continuous(limits = c(0, NA)) +  # y 轴下边界为 0
  labs(
    title = "Mantel Test Scatter Plot",
    x = "Distance matrix: landscape pattern",
    y = "Distance matrix: elements",
    caption = paste0("Mantel r = ", round(mantel_result$statistic, 3), ", p = ", mantel_result$signif)
  ) +
  # theme_minimal(base_family = "Times New Roman") +  # 设置 Times New Roman 字体
  theme(
    panel.background = element_rect(fill = "white", color = NA),  # 图形背景为白色
    plot.background = element_rect(fill = "white", color = NA),  # 整体背景为白色
    axis.line = element_line(color = "gray50", size = 0.8),  # XY轴线为黑色
    panel.grid.major = element_line(color = "gray80", size = 0.5),  # 主网格线为浅灰色
    panel.grid.minor = element_line(color = "gray90", size = 0.3),  # 次网格线为更浅的灰色
    # panel.grid.major = element_blank(),  # 移除主网格线
    # panel.grid.minor = element_blank(),   # 移除次网格线
    axis.title = element_text(size = 10, face = "bold"),  # 双轴标题字号 7
    axis.text = element_text(size = 10),  # 双轴刻度字号 7
    plot.caption = element_text(size = 10, hjust = 0.5),  # caption 字号 5
    plot.title = element_text(size = 12, face = "bold", hjust = 0.5)  # 标题字号 7
  )

# 打印绘图
print(p_mantel)

# 保存图像为PDF格式
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_Mantel.pdf", plot = p_mantel, width = 8, height = 8, device = "pdf")

# 保存图像为JPEG格式
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_Mantel.jpg", plot = p_mantel, width = 8, height = 8, dpi = 300, device = "jpeg")


# p_mantel_R2 <- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   labs(
#     title = "Mantel Test Scatter Plot",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements"
#   ) +
#   annotate(
#     "text",
#     x = max(df_mantel$X2_dist) * 0.8,
#     y = max(df_mantel$X1_dist) * 0.9,
#     label = paste0("Mantel r = ", round(mantel_result$statistic, 3),", p = ", mantel_result$signif),
#     color = "black",
#     size = 5
#   ) +
#   theme_minimal()
# 
# print(p_mantel_R2)
# 
# 
# # #保存mantel
# # 保存图像为PDF格式
# ggsave("D:/Code/R/BBNP/MRM/Result/OPMC_Mantel_R2.pdf", plot = p_mantel, width = 8, height = 8, device = "pdf")
# 
# # 保存图像为JPEG格式
# ggsave("D:/Code/R/BBNP/MRM/Result/OPMC_Mantel_R2.jpg", plot = p_mantel, width = 8, height = 8, dpi = 300, device = "jpeg")




#6.MRM可视化
library(ggplot2)
# library(extrafont)

# 绘制散点图和拟合线

# 未设置字体字号
# p_mrm <- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   labs(
#     title = "MRM Analysis Scatter Plot",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements",
#     caption = paste0("R² = ", round(mrm_result$r.squared[1], 3),
#                      ", p = ", round(mrm_result$r.squared[2], 3)),
#     color = "black",
#     size = 5
#   ) +
#   theme_minimal()

# 设置字体字号
p_mrm<- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "black", alpha = 0.4) +
  geom_smooth(method = "lm", col = "black") +
  labs(
    title = "MRM Analysis Scatter Plot",
    x = "Distance matrix: landscape pattern",
    y = "Distance matrix: elements",
    caption = paste0("R² = ", round(mrm_result$r.squared[1], 3), ", p = ", round(mrm_result$r.squared[2], 3))
  ) +
  theme(
    panel.background = element_rect(fill = "white", color = NA),  # 图形背景为白色
    plot.background = element_rect(fill = "white", color = NA),  # 整体背景为白色
    axis.line = element_line(color = "gray50", size = 0.8),  # XY轴线为黑色
    panel.grid.major = element_line(color = "gray80", size = 0.5),  # 主网格线为浅灰色
    panel.grid.minor = element_line(color = "gray90", size = 0.3),  # 次网格线为更浅的灰色
    # panel.grid.major = element_blank(),  # 移除主网格线
    # panel.grid.minor = element_blank(),   # 移除次网格线
    axis.title = element_text(size = 10, face = "bold"),  # 双轴标题字号 7
    axis.text = element_text(size = 10),  # 双轴刻度字号 7
    plot.caption = element_text(size = 10, hjust = 0.5),  # caption 字号 5
    plot.title = element_text(size = 12, face = "bold", hjust = 0.5)  # 标题字号 7
  )

print(p_mrm)

#保存图像为PDF格式
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_MRM.pdf", plot = p_mrm, width = 8, height = 8, device = "pdf")

# 保存图像为JPEG格式
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_MRM.jpg", plot = p_mrm, width = 8, height = 8, dpi = 300, device = "jpeg")



# # R2
# p_mrm_R2 <- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
#   geom_point(color = "black", alpha = 0.4) +
#   geom_smooth(method = "lm", col = "black") +
#   labs(
#     title = "MRM Analysis Scatter Plot",
#     x = "Distance matrix: landscape pattern",
#     y = "Distance matrix: elements"
#   ) +
#   annotate(
#     "text",
#     x = max(df_mantel$X2_dist) * 0.8,
#     y = max(df_mantel$X1_dist) * 0.9,
#     label = paste0("R² = ", round(mrm_result$r.squared[1], 3),
#                    ", p = ", round(mrm_result$r.squared[2], 3)),
#     color = "black",
#     size = 5
#   ) +
#   theme_minimal()
# 
# print(p_mrm_R2)
# 
# # 保存MRM
# #保存图像为PDF格式
# ggsave("D:/Code/R/BBNP/MRM/Result/EBMC_MRM_R2.pdf", plot = p_mrm_R2, width = 8, height = 8, device = "pdf")
# 
# # 保存图像为JPEG格式+图例
# ggsave("D:/Code/R/BBNP/MRM/Result/EBMC_MRM_R2.jpg", plot = p_mrm_R2, width = 8, height = 8, dpi = 300, device = "jpeg")







