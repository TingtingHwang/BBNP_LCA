_base_ = [
    '../_base_/models/upernet_swin.py', '../_base_/datasets/lct.py',
    '../_base_/default_runtime.py', '../_base_/schedules/schedule_160k.py'
]
model = dict(
    backbone=dict(
        type='SwinTransformerAng',
        img_size=512,
        radius_cuts=64,
        azimuth_cuts=256,
        in_chans=3,
        num_classes=58,
        embed_dim=96,
        depths=[2, 2, 6, 2],
        num_heads=[3, 6, 12, 24],
        distortion_model='polynomial',
        window_size=(1, 16),
        mlp_ratio=4,
        qkv_bias=True,
        qk_scale=None,
        drop_rate=0.0,
        drop_path_rate=0.1,
        ape=False,
        patch_norm=True,
        use_checkpoint=False,
        n_radius=10,
        n_azimuth=10
    ),
    decode_head=dict(
        in_channels=[96, 192, 384, 768],
        num_classes=58
    ),
    auxiliary_head=dict(
        in_channels=384,
        num_classes=58
    ))

# AdamW optimizer, no weight decay for position embedding & layer norm in backbone
optimizer = dict(_delete_=True, type='AdamW', lr=0.00006, betas=(0.9, 0.999), weight_decay=0.01,
                 paramwise_cfg=dict(custom_keys={'absolute_pos_embed': dict(decay_mult=0.),
                                                 'relative_position_bias_table': dict(decay_mult=0.),
                                                 'norm': dict(decay_mult=0.)}))

lr_config = dict(_delete_=True, policy='poly',
                 warmup='linear',
                 warmup_iters=1500,
                 warmup_ratio=1e-6,
                 power=1.0, min_lr=0.0, by_epoch=False)

# By default, models are trained on 8 GPUs with 1 images per GPU
data=dict(samples_per_gpu=2)

work_dir = 'work_dirs/swinclustering_lct'
out_dir = 'work_dirs/swinclustering_lct'

runner = dict(type='IterBasedRunner', max_iters=50000)
checkpoint_config = dict(by_epoch=False, interval=1000)
evaluation = dict(interval=1000, metric='mIoU')


