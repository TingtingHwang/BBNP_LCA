# 0. load package
# install.packages(c("vegan", "ecodist", "ggplot2"))
library(ecodist)
library(ggplot2)
library(permute)
library(lattice)
library(vegan)
# 1. Data preprocessing 
#Setting the Run Folder
setwd("D:/Code/R/BBNP/MRM/")

# Converting X1 and X2 into a distance matrix
# load data
X1 <- read.csv("./Data/SOFM_Element.csv", row.names = 1)   
X2 <- read.csv("./Data/SOFM_Frag.csv", row.names = 1)# 

# Calculation of the distance matrix
dist_X1 <- vegdist(X1, method = "bray")# Bray-Curtis distance
dist_X2 <- vegdist(X2, method = "euclidean")# Euclidean distance

# show(dist_X1)


# 2. check data
# create data frame
df <- data.frame(X1_dist = as.vector(dist_X1), X2_dist = as.vector(dist_X2))

# Scatterplotting
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


# 3. Handling of outliers
# Calculate IQR (interquartile range)
iqr_X1 <- IQR(df$X1_dist)
iqr_X2 <- IQR(df$X2_dist)

# Define upper and lower limits
#opmc
# lower_bound_X1 <- quantile(df$X1_dist, 0.18) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.30) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.25) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

#STSC
# lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.75) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.25) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

#SOFM
lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
upper_bound_X1 <- quantile(df$X1_dist, 0.55) + 1.5 * iqr_X1
lower_bound_X2 <- quantile(df$X2_dist, 0.1) - 1.5 * iqr_X2
upper_bound_X2 <- quantile(df$X2_dist, 0.75) + 1.5 * iqr_X2

#EBMC
# lower_bound_X1 <- quantile(df$X1_dist, 0.25) - 1.5 * iqr_X1
# upper_bound_X1 <- quantile(df$X1_dist, 0.75) + 1.5 * iqr_X1
# lower_bound_X2 <- quantile(df$X2_dist, 0.15) - 1.5 * iqr_X2
# upper_bound_X2 <- quantile(df$X2_dist, 0.25) + 1.5 * iqr_X2


# Marking outliers
df$outlier <- with(df, 
                   (X1_dist < lower_bound_X1 | X1_dist > upper_bound_X1) |
                     (X2_dist < lower_bound_X2 | X2_dist > upper_bound_X2))

#Visual flagging of outliers
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

# View outliers
outliers <- df[df$outlier, ]
print(outliers)

# Remove outliers
df_clean <- df[!df$outlier, ]

# Re-fit model
model_clean <- lm(X1_dist ~ X2_dist, data = df_clean)

# plot
summary(model_clean)

# Re-plotting the scatterplot
library(ggplot2)
ggplot(df_clean, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "blue") +
  geom_smooth(method = "lm", col = "red") +
  labs(title = "Scatter Plot without Outliers",
       x = "Distance Matrix X2",
       y = "Distance Matrix X1") +
  theme_minimal()


# Replacing outliers with medians
df$X1_dist[df$outlier] <- median(df$X1_dist, na.rm = TRUE)
df$X2_dist[df$outlier] <- median(df$X2_dist, na.rm = TRUE)


# Re-generate the original data matrix
# Construct the original matrix from the replaced df
n <- sqrt(2 * nrow(df) + 0.25) - 0.5  # Compute the matrix dimension n
matrix_X1 <- matrix(0, nrow = n, ncol = n)
matrix_X2 <- matrix(0, nrow = n, ncol = n)

# Fill the lower triangle of the matrix
matrix_X1[lower.tri(matrix_X1)] <- df$X1_dist
matrix_X2[lower.tri(matrix_X2)] <- df$X2_dist

# Symmetrization matrix
matrix_X1 <- matrix_X1 + t(matrix_X1)
matrix_X2 <- matrix_X2 + t(matrix_X2)

# Re-generate the distance matrix
dist_X1_clean <- as.dist(matrix_X1)
dist_X2_clean <- as.dist(matrix_X2)


# 4. Mantel test analysis
# Install and load the vegan package
# install.packages("vegan")
library(vegan)

# Mantel test
mantel_result <- vegan::mantel(dist_X1_clean, dist_X2_clean, permutations = 999, method = "spearman")#spearman
# mantel_result <- vegan::mantel(dist_X1, dist_X2, permutations = 999, method = "spearman")#spearman

# print
print(mantel_result)



# 5. MRM
# Install and load the ecodist package
# install.packages("ecodist")
library(ecodist)

# Perform MRM analyses
mrm_result <- MRM(dist_X1_clean ~ dist_X2_clean, nperm = 999)
# mrm_result <- MRM(dist_X1 ~ dist_X2, nperm = 999)

# print
print(mrm_result)

###############Visualisation
# 6.Mantel visualisation
# Visualisation
df_mantel <- data.frame(
  X1_dist = as.vector(as.matrix(dist_X1_clean)),
  X2_dist = as.vector(as.matrix(dist_X2_clean))
)


# Load library
library(ggplot2)

# Creating a plot
p_mantel <- ggplot(df_mantel, aes(x = X2_dist, y = X1_dist)) +
  geom_point(color = "black", alpha = 0.4) +
  geom_smooth(method = "lm", col = "black") +
  scale_y_continuous(limits = c(0, NA)) +  # The lower boundary of the y-axis is 0
  labs(
    title = "Mantel Test Scatter Plot",
    x = "Distance matrix: landscape pattern",
    y = "Distance matrix: elements",
    caption = paste0("Mantel r = ", round(mantel_result$statistic, 3), ", p = ", mantel_result$signif)
  ) +
  theme(
    panel.background = element_rect(fill = "white", color = NA),  # white background
    plot.background = element_rect(fill = "white", color = NA),  # whole white background
    axis.line = element_line(color = "gray50", size = 0.8),  # black XY axis 
    panel.grid.major = element_line(color = "gray80", size = 0.5),  # Main grid lines in light grey
    panel.grid.minor = element_line(color = "gray90", size = 0.3),  # Sub-grid lines are lighter grey
    axis.title = element_text(size = 10, face = "bold"),  # Biaxial title font size 
    axis.text = element_text(size = 10),  # Biaxial scale font size
    plot.caption = element_text(size = 10, hjust = 0.5),  # caption front size
    plot.title = element_text(size = 12, face = "bold", hjust = 0.5)  # Tittle front size
  )

# print
print(p_mantel)

# save as .pdf
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_Mantel.pdf", plot = p_mantel, width = 8, height = 8, device = "pdf")

# save as .jpeg
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_Mantel.jpg", plot = p_mantel, width = 8, height = 8, dpi = 300, device = "jpeg")


# 7.MRM visualisation
library(ggplot2)
# library(extrafont)

# Creating a plot
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
    panel.background = element_rect(fill = "white", color = NA),  # white background
    plot.background = element_rect(fill = "white", color = NA),  # white background
    axis.line = element_line(color = "gray50", size = 0.8),  # black XY axis 
    panel.grid.major = element_line(color = "gray80", size = 0.5),  # Main grid lines in light grey
    panel.grid.minor = element_line(color = "gray90", size = 0.3),  # Sub-grid lines are lighter grey
    axis.title = element_text(size = 10, face = "bold"),  # Biaxial title font size 
    axis.text = element_text(size = 10),  # Biaxial scale font size
    plot.caption = element_text(size = 10, hjust = 0.5),  # caption front size
    plot.title = element_text(size = 12, face = "bold", hjust = 0.5)  # Tittle front size
  )

print(p_mrm)

# save as .pdf
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_MRM.pdf", plot = p_mrm, width = 8, height = 8, device = "pdf")

# save as .jpeg
ggsave("D:/Code/R/BBNP/MRM/Result/STSC_MRM.jpg", plot = p_mrm, width = 8, height = 8, dpi = 300, device = "jpeg")







