# BBNP_LCA

**Official Implementation of "Advancing Landscape Characterization: A Comparative Study of Machine Learning and Manual Classification Methods with Insights from Bannau Brycheiniog National Park, Wales."**
This repository contains the official codes for our paper, organized into seven components:  
1. Data, 2. VIF & TOL Validation, 3. Clustering Methods, 4. CVI Plotting, 5. SHAP Analysis, 6. Mantel_MRM Analysis, and 7. Cross-Validation.  


## Version Information  
**Latest Release**: [v1.0.0](https://github.com/TingtingHwang/BBNP_LCA/releases/tag/v1.0.0)  
**Review Response Version**: [v1.0.0-review-response](https://github.com/TingtingHwang/BBNP_LCA/commit/a1b2c3d)  

---

## 1. Data  
The dataset includes the following **7 geospatial layers** (processed into aligned GeoTIFF format (ISO 19115-33 compliant)):  
- **Altitude**: Sourced from [NASA EARTHDATA](https://earthdata.nasa.gov/).  
- **Geology**: Sourced from [BGS Geology](https://www.bgs.ac.uk/).  
- **Historic**: Sourced from [Landmap](https://www.landmap.ac.uk/).  
- **Landcover**: Sourced from [Living Wales](https://livingwales.uk/).  
- **Landform**: Sourced from [Landmap](https://www.landmap.ac.uk/).  
- **Soilscape**: Sourced from [UK Soil Observatory](https://www.ukso.org/).  
- **Vegetation**: Sourced from [Living Wales](https://livingwales.uk/).  

**Manual.tif** (manually annotated ground truth data) was created by **Steven Warnock**. To access this file, please contact him **swarnock@livland.eclipse.co.uk** for his permission.

---

## 2. VIF & TOL Validation  
Run `processing.m` to compute Variance Inflation Factor (VIF) and Tolerance (TOL).  
- The `lib` folder contains preprocessing utilities for TIFF images (background removal, boundary alignment, and normalization).  

---

## 3. Clustering Methods  

### (1) OPMC Clustering  
- Navigate to `OPMC/` and run `OPMC_LCA_Final.m`.  
- **Loop iterations**: 2–30 (representing varying cluster numbers).  
- Results:  
  - CVI metrics (SC, DB, CH, KL) saved in `results_CVI/`.  
  - Output TIFF images saved in `results_tif/`.  

### (2) SOFM Clustering  
- Navigate to `SOFM/` and run `SOFM_LCA_Final.m`.  
- **Loop iterations**: 2–30.  
- Results:  
  - CVI metrics (SC, DB, CH, KL) saved in `results_CVI/`.  
  - Output TIFF images saved in `results_tif/`.  

### (3) STSC Clustering  
#### Step 1: Generate Training Data  
- Navigate to `STSC/make_train_dataset/` and run `make_train_dataset.m`.  
- Output dataset: `STSC/make_train_dataset/dataset_BBNP1x1_7Channels/`.  

#### Step 2: Configure Environment  
1. Create a Conda environment:  
   ```bash  
   conda create --name BBNP python=3.7 -y  
   conda activate BBNP  
   ```  
2. Install PyTorch and TorchVision:  
   ```bash  
   pip install torch===1.8.1+cu111 -f https://download.pytorch.org/whl/torch_stable.html  
   pip install torchvision===0.9.1+cu111 -f https://download.pytorch.org/whl/torch_stable.html  
   ```  
3. Install MMCV:  
   ```bash  
   pip install -U openmim  
   mim install mmcv-full==1.2.4 -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.8.0/index.html  
   ```  
4. Install dependencies in the project root:  
   ```bash  
   pip install mmsegmentation  
   pip install -v -e .  
   ```  
5. Download the pretrained Swin Transformer model from [Google Drive](https://drive.google.com/file/d/1bUFuZ3tI6nUyVTMsDqZi85ltvf9REbla/view?usp=sharing) and place it in `models/`.  

#### Step 3: Training  
Run the following command:  
```bash  
python tools/train.py configs/swin/swinclustering_lct.py --options model.pretrained=models/swin_tiny_patch4_window7_224.pth  
```  

#### Step 4: Testing  
Run the following command:  
```bash  
python tools/lca_test.py configs/swin/swinclustering_lct.py work_dirs/swinclustering_lct_1x1_20_BBNP/iter_4000.pth --save_name STSC_BBNP 
```  
Our trained model [Google Drive](https://drive.google.com/file/d/1QYr5O35TniYFjxEmC98w7zReswq9-gHC/view?usp=sharing) is also provided for direct use. Results will be saved in `results/`.

---

## 4. CVI Plotting  
Run `Fig_CVI_3models.m` in `Draw_CVI/` to generate line plots for DB and SC metrics using results from Step 3.  

---

## 5. SHAP Analysis  
1. Preprocess data:  
   - Navigate to `5_SHAP/data/` and run `data_preprocessing.m`.  
2. Run SHAP analysis:  
   - Navigate to `5_SHAP/` and execute `python main_LCA.py`.  

**Dependencies**:  
```bash  
pip install lightgbm shap matplotlib scikit-learn xarray  
```  

---

## 6. Mantel & MRM Analysis  
Navigate to `6_Mantel_MRM/` and run `Mantel_MRM.R` using R. Results will be saved in `Result/`.  

---

## 7. Cross-Validation  
Run `compareLCA.m` in `7_CrossValidation/` to perform cross-validation between any two clustering results.  

---

For any questions, please contact Tingting Huang (**huangtt17@bjfu.edu.cn**).  
