# --------------------------------------------------------
# Swin Transformer
# Copyright (c) 2021 Microsoft
# Licensed under The MIT License [see LICENSE for details]
# Written by Ze Liu
# --------------------------------------------------------

# from curses import window
import torch
import torch.nn as nn
import numpy as np
import torch.utils.checkpoint as checkpoint
from timm.models.layers import DropPath, to_2tuple, trunc_normal_
from .utils import get_sample_params_from_subdiv, get_sample_locations
from mmseg.utils import get_root_logger
from mmcv_custom import load_checkpoint
from ..builder import BACKBONES
import math

pi = 3.141592653589793


class Mlp(nn.Module):
    def __init__(self, in_features, hidden_features=None, out_features=None, act_layer=nn.GELU, drop=0.):
        super().__init__()
        out_features = out_features or in_features
        hidden_features = hidden_features or in_features
        self.fc1 = nn.Linear(in_features, hidden_features)
        self.act = act_layer()
        self.fc2 = nn.Linear(hidden_features, out_features)
        self.drop = nn.Dropout(drop)

    def forward(self, x):
        x = self.fc1(x)
        x = self.act(x)
        x = self.drop(x)
        x = self.fc2(x)
        x = self.drop(x)
        return x

def R(window_size, num_heads, radius, D, a_r, b_r, r_max):
    # import pdb;pdb.set_trace()
    a_r = a_r[radius.view(-1)].reshape(window_size[0]*window_size[1], window_size[0]*window_size[1], num_heads)
    b_r = b_r[radius.view(-1)].reshape(window_size[0]*window_size[1], window_size[0]*window_size[1], num_heads)
    radius = radius[None, :, None, :].repeat(num_heads, 1, D.shape[0], 1) # num_heads, wh, num_win*B, ww
    radius = D*radius

    radius = radius.transpose(0,1).transpose(1,2).transpose(2,3).transpose(0,1)

    # A_r = torch.zeros(window_size[0]*window_size[1], window_size[0]*window_size[1], num_heads).cuda()
    A_r = a_r*torch.cos(radius*2*pi/r_max) + b_r*torch.sin(radius*2*pi/r_max)
    
    return A_r

def theta(window_size, num_heads, radius, theta_max, a_r, b_r, H): # change theta_max to D
    a_r = a_r[radius]
    b_r = b_r[radius]
    radius = radius*theta_max/H
    radius = radius[:, :, None].repeat(1, 1, num_heads)
    A_r = a_r*torch.cos(radius) + b_r*torch.sin(radius)
    
    return A_r

def phi(window_size, num_heads, azimuth, a_p, b_p, W):
    a_p = a_p[azimuth]
    b_p = b_p[azimuth]
    azimuth = azimuth*2*np.pi/W
    azimuth = azimuth[:, :, None].repeat(1, 1, num_heads)

    A_phi = a_p*torch.cos(azimuth) + b_p*torch.sin(azimuth)
    # import pdb;pdb.set_trace()
    return A_phi 

def window_partition(x, window_size, D_s):
    """
    Args:
        x: (B, H, W, C)
        window_size (int): window size

    Returns:
        windows: (num_windows*B, window_size, window_size, C)
    """
    # print(x.shape)
    B, H, W, C = x.shape
    # import pdb;pdb.set_trace()
    if type(window_size) is tuple:
        x = x.view(B, H // window_size[0], window_size[0], W // window_size[1], window_size[1], C)
        D_s = D_s.view(B, H // window_size[0], window_size[0], W // window_size[1], window_size[1])
        windows = x.permute(0, 1, 3, 2, 4, 5).contiguous().view(-1, window_size[0], window_size[1], C)
        windows_d = D_s.permute(0, 1, 3, 2, 4).contiguous().view(-1, window_size[0], window_size[1])
        return windows, windows_d
    else:
        x = x.view(B, H // window_size, window_size, W // window_size, window_size, C)
        D_s = D_s.view(B, H // window_size, window_size, W // window_size, window_size)
        windows = x.permute(0, 1, 3, 2, 4, 5).contiguous().view(-1, window_size, window_size, C)
        windows_d = D_s.permute(0, 1, 3, 2, 4).contiguous().view(-1, window_size, window_size)
        return windows, windows_d


def window_reverse(windows, D_windows, window_size, H, W):
    """
    Args:
        windows: (num_windows*B, window_size, window_size, C)
        window_size (int): Window size
        H (int): Height of image
        W (int): Width of image

    Returns:
        x: (B, H, W, C)
    """
    
    if type(window_size) is tuple:
        B = int(windows.shape[0] / (H * W / window_size[0] / window_size[1]))
        x = windows.view(B, H // window_size[0], W // window_size[1], window_size[0], window_size[1], -1)
        D_s = D_windows.view(B, H // window_size[0], W // window_size[1], window_size[0], window_size[1])
    else:
        B = int(windows.shape[0] / (H * W / window_size / window_size))
        x = windows.view(B, H // window_size, W // window_size, window_size, window_size, -1)
        D_s = D_windows.view(B, H // window_size, W // window_size, window_size, window_size)
    x = x.permute(0, 1, 3, 2, 4, 5).contiguous().view(B, H, W, -1)
    D_s = D_s.permute(0, 1, 3, 2, 4).contiguous().view(B, H, W)
    # import pdb;pdb.set_trace()
    return x, D_s


class WindowAttention(nn.Module):
    r""" Window based multi-head self attention (W-MSA) module with relative position bias.
    It supports both of shifted and non-shifted window.

    Args:
        dim (int): Number of input channels.
        window_size (tuple[int]): The height and width of the window.
        num_heads (int): Number of attention heads.
        qkv_bias (bool, optional):  If True, add a learnable bias to query, key, value. Default: True
        qk_scale (float | None, optional): Override default qk scale of head_dim ** -0.5 if set
        attn_drop (float, optional): Dropout ratio of attention weight. Default: 0.0
        proj_drop (float, optional): Dropout ratio of output. Default: 0.0
    """

    def __init__(self, patch_size, input_resolution, dim, window_size, num_heads, qkv_bias=True, qk_scale=None, attn_drop=0., proj_drop=0.):
        # import pdb;pdb.set_trace()
        super().__init__()
        # print("window_size", window_size)
        # import pdb;pdb.set_trace()
        self.dim = dim
        self.input_resolution = input_resolution
        self.patch_size = patch_size
        self.window_size = window_size  # Wh, Ww
        self.num_heads = num_heads
        head_dim = dim // num_heads
        self.scale = qk_scale or head_dim ** -0.5
        H, W = input_resolution

        # define a parameter table of relative position bias
        # self.relative_position_bias_table = nn.Parameter(
        #     torch.zeros((2 * window_size[0] - 1) * (2 * window_size[1] - 1), num_heads))  # 2*Wh-1 * 2*Ww-1, nH
        # self.a_p = nn.Parameter(
        #     torch.zeros(9, num_heads))
        # self.b_p = nn.Parameter(
        #     torch.zeros(8, num_heads))
        # self.a_r = nn.Parameter(
        #     torch.zeros(9, num_heads))
        # self.b_r = nn.Parameter(
        #     torch.zeros(8, num_heads))
        

        if input_resolution == window_size:
            self.a_p = nn.Parameter(
                torch.zeros(window_size[1], num_heads))
            self.b_p = nn.Parameter(
                torch.zeros(window_size[1], num_heads))
        else:
            self.a_p = nn.Parameter(
                torch.zeros((2 * window_size[1] - 1), num_heads))
            self.b_p = nn.Parameter(
                torch.zeros((2 * window_size[1] - 1), num_heads))
        self.a_r = nn.Parameter(
            torch.zeros((2 * window_size[0] - 1), num_heads))
        self.b_r = nn.Parameter(
            torch.zeros((2 * window_size[0] - 1), num_heads))

        # get pair-wise relative position index for each token inside the window
        coords_h = torch.arange(self.window_size[0])
        coords_w = torch.arange(self.window_size[1])
        coords = torch.stack(torch.meshgrid([coords_h, coords_w]))  # 2, Wh, Ww
        coords_flatten = torch.flatten(coords, 1)  # 2, Wh*Ww
        relative_coords = coords_flatten[:, :, None] - coords_flatten[:, None, :]  # 2, Wh*Ww, Wh*Ww
        relative_coords = relative_coords.permute(1, 2, 0).contiguous()  # Wh*Ww, Wh*Ww, 2
        radius = (relative_coords[:, :, 0]).cuda()
        azimuth = (relative_coords[:, :, 1]).cuda()
        r_max = patch_size[0]*H
        # print("patch_size", patch_size[0], "azimuth", 2*np.pi/W, "r_max", r_max)
        self.r_max = r_max
        self.radius = radius
        self.azimuth = azimuth

        # relative_coords[:, :, 0] += self.window_size[0] - 1  # shift to start from 0
        # relative_coords[:, :, 1] += self.window_size[1] - 1
        # relative_coords[:, :, 0] *= 2 * self.window_size[1] - 1
        # relative_position_index = relative_coords.sum(-1)  # Wh*Ww, Wh*Ww
        # self.register_buffer("relative_position_index", relative_position_index)

        self.qkv = nn.Linear(dim, dim * 3, bias=4)
        self.attn_drop = nn.Dropout(attn_drop)
        self.proj = nn.Linear(dim, dim)
        self.proj_drop = nn.Dropout(proj_drop)
        # trunc_normal_(self.relative_position_bias_table, std=.02)
        trunc_normal_(self.a_p, std=.02)
        trunc_normal_(self.a_r, std=.02)
        trunc_normal_(self.b_p, std=.02)
        trunc_normal_(self.b_r, std=.02)
        self.softmax = nn.Softmax(dim=-1)

    def forward(self, x, D, theta_max, mask=None):
        """
        Args:
            x: input features with shape of (num_windows*B, N, C)
            mask: (0/-inf) mask with shape of (num_windows, Wh*Ww, Wh*Ww) or Nonem

        """

        B_, N, C = x.shape
        # import pdb;pdb.set_trace()
        qkv = self.qkv(x).reshape(B_, N, 3, self.num_heads, C // self.num_heads).permute(2, 0, 3, 1, 4)
        q, k, v = qkv[0], qkv[1], qkv[2]  # make torchscript happy (cannot use tensor as tuple)

        q = q * self.scale
        attn = (q @ k.transpose(-2, -1))

        # relative_position_bias = self.relative_position_bias_table[self.relative_position_index.view(-1)].view(
        #     self.window_size[0] * self.window_size[1], self.window_size[0] * self.window_size[1], -1)  # Wh*Ww,Wh*Ww,nH
        # relative_position_bias = relative_position_bias.permute(2, 0, 1).contiguous()  # nH, Wh*Ww, Wh*Ww

        A_phi = phi(self.window_size, self.num_heads, self.azimuth, self.a_p, self.b_p, self.input_resolution[1])
        A_theta = theta(self.window_size, self.num_heads, self.radius, theta_max, self.a_r, self.b_r, self.input_resolution[0]) # change input_resolution[0] to r_max
        # A_r = R(self.window_size, self.num_heads, self.radius, D, self.a_r, self.b_r, self.r_max)
        attn = attn + A_phi.transpose(1, 2).transpose(0, 1).unsqueeze(0) + A_theta.transpose(1, 2).transpose(0, 1).unsqueeze(0) 

        if mask is not None:
            nW = mask.shape[0]
            attn = attn.view(B_ // nW, nW, self.num_heads, N, N) + mask.unsqueeze(1).unsqueeze(0)
            attn = attn.view(-1, self.num_heads, N, N)
            attn = self.softmax(attn)
        else:
            attn = self.softmax(attn)

        attn = self.attn_drop(attn)

        x = (attn @ v).transpose(1, 2).reshape(B_, N, C)
        x = self.proj(x)
        x = self.proj_drop(x)
        return x

    def extra_repr(self) -> str:
        return f'dim={self.dim}, window_size={self.window_size}, num_heads={self.num_heads}'

    def flops(self, N):
        # calculate flops for 1 window with token length of N
        flops = 0
        # qkv = self.qkv(x)
        flops += N * self.dim * 3 * self.dim
        # attn = (q @ k.transpose(-2, -1))
        flops += self.num_heads * N * (self.dim // self.num_heads) * N
        #  x = (attn @ v)
        flops += self.num_heads * N * N * (self.dim // self.num_heads)
        # x = self.proj(x)
        flops += N * self.dim * self.dim
        return flops


class SwinTransformerBlock(nn.Module):
    r""" Swin Transformer Block.

    Args:
        dim (int): Number of input channels.
        input_resolution (tuple[int]): Input resulotion.
        num_heads (int): Number of attention heads.
        window_size (int): Window size.
        shift_size (int): Shift size for SW-MSA.
        mlp_ratio (float): Ratio of mlp hidden dim to embedding dim.
        qkv_bias (bool, optional): If True, add a learnable bias to query, key, value. Default: True
        qk_scale (float | None, optional): Override default qk scale of head_dim ** -0.5 if set.
        drop (float, optional): Dropout rate. Default: 0.0
        attn_drop (float, optional): Attention dropout rate. Default: 0.0
        drop_path (float, optional): Stochastic depth rate. Default: 0.0
        act_layer (nn.Module, optional): Activation layer. Default: nn.GELU
        norm_layer (nn.Module, optional): Normalization layer.  Default: nn.LayerNorm
    """

    def __init__(self, dim, patch_size, input_resolution, num_heads, window_size=7, shift_size=0,
                 mlp_ratio=4., qkv_bias=True, qk_scale=None, drop=0., attn_drop=0., drop_path=0.,
                 act_layer=nn.GELU, norm_layer=nn.LayerNorm):
        super().__init__()
        self.dim = dim
        self.input_resolution = input_resolution
        self.num_heads = num_heads
        self.patch_size = patch_size
        #self.num_mlps = radius_cuts # pass radius cuts as arguement 
        self.window_size = window_size
        self.shift_size = shift_size
        self.mlp_ratio = mlp_ratio
        # import pdb;pdb.set_trace()
        if self.input_resolution[1] < self.window_size[1]:  #azimuth values is input_resolution[1] window starts including radius
            residue = self.window_size[1]//self.input_resolution[1]
            self.window_size = (self.window_size[0]*residue, self.window_size[1]//residue)
            # self.window_size = (min(self.input_resolution),self.input_resolution[1]) 
            self.attn = WindowAttention(
            patch_size, input_resolution, dim, window_size=self.window_size, num_heads=num_heads,
            qkv_bias=qkv_bias, qk_scale=qk_scale, attn_drop=attn_drop, proj_drop=drop)
            assert 0 <= self.shift_size[0] < self.window_size[0], "shift_size must in 0-window_size[0]"
        else: #window along pure azimuth 
            self.attn = WindowAttention(
            patch_size, input_resolution, dim, window_size=to_2tuple(self.window_size), num_heads=num_heads,
            qkv_bias=qkv_bias, qk_scale=qk_scale, attn_drop=attn_drop, proj_drop=drop)
            assert 0 <= self.shift_size[1] < self.window_size[1], "shift_size must in 0-window_size[1]"

        self.norm1 = norm_layer(dim)
        # print("swin_transformers block", self.window_size)


        self.drop_path = DropPath(drop_path) if drop_path > 0. else nn.Identity()
        self.norm2 = norm_layer(dim)
        mlp_hidden_dim = int(dim * mlp_ratio)
        self.mlp = Mlp(in_features=dim, hidden_features=mlp_hidden_dim, act_layer=act_layer, drop=drop)

        if self.shift_size  > (0, 0):
            # calculate attention mask for SW-MSA
            H, W = self.input_resolution
            img_mask = torch.zeros((1, H, W, 1))  # 1 H W 1
            D_s = torch.zeros((1, H, W))  # 1 H W 1
            h_slices = (slice(0, -self.window_size[0]),
                        slice(-self.window_size[0], -self.shift_size[0]),
                        slice(-self.shift_size[0], None))
            w_slices = (slice(0, -self.window_size[1]),
                        slice(-self.window_size[1], -self.shift_size[1]),
                        slice(-self.shift_size[1], None))
            cnt = 0
            for h in h_slices:
                for w in w_slices:
                    img_mask[:, h, w, :] = cnt
                    cnt += 1

            mask_windows, D_s_windows = window_partition(img_mask, self.window_size, D_s)  # nW, window_size, window_size, 1

            mask_windows = mask_windows.view(-1, self.window_size[0] * self.window_size[1])
            D_s_windows = D_s_windows.view(-1, self.window_size[0] * self.window_size[1])
            attn_mask = mask_windows.unsqueeze(1) - mask_windows.unsqueeze(2)
            attn_mask = attn_mask.masked_fill(attn_mask != 0, float(-100.0)).masked_fill(attn_mask == 0, float(0.0))
        else:
            attn_mask = None

        self.register_buffer("attn_mask", attn_mask)

    def forward(self, x, D_s, theta_max):
        # print("SwinTransformerBlock")
        
        # import pdb;pdb.set_trace()
        H, W = self.input_resolution
        # print(H, W, self.input_resolution, self.window_size)
        # breakpoint()
        B, L, C = x.shape
        assert L == H * W, "input feature has wrong size"

        shortcut = x
        x = self.norm1(x)
        x = x.view(B, H, W, C)

        # cyclic shift
        if self.shift_size > (0, 0):
            shifted_x = torch.roll(x, shifts=(-self.shift_size[0], -self.shift_size[1]), dims=(1, 2))
        else:
            shifted_x = x

        # partition windows
        x_windows, D_windows = window_partition(shifted_x, self.window_size, D_s)  # nW*B, window_size, window_size, C
        if type(self.window_size) is tuple:
            x_windows = x_windows.view(-1, self.window_size[0] * self.window_size[1], C)
            D_windows = D_windows.view(-1, self.window_size[0] * self.window_size[1])  # nW*B, window_size*window_size, C

            # W-MSA/SW-MSA
            attn_windows = self.attn(x_windows, D_windows, theta_max, mask=self.attn_mask)  # nW*B, window_size*window_size, C

            # merge windows
            attn_windows = attn_windows.view(-1, self.window_size[0], self.window_size[1], C)
        else:
            x_windows = x_windows.view(-1, self.window_size * self.window_size, C)  # nW*B, window_size*window_size, C
            D_windows = D_windows.view(-1, self.window_size * self.window_size)
            # W-MSA/SW-MSA
            attn_windows = self.attn(x_windows, D_windows, mask=self.attn_mask)  # nW*B, window_size*window_size, C

            # merge windows
            attn_windows = attn_windows.view(-1, self.window_size, self.window_size, C)

        shifted_x, D_s = window_reverse(attn_windows, D_windows, self.window_size, H, W)  # B H' W' C

        # reverse cyclic shift
        if self.shift_size > (0, 0):
            x = torch.roll(shifted_x, shifts=(self.shift_size[0], self.shift_size[1]), dims=(1, 2))
        else:
            x = shifted_x
        x = x.view(B, H * W, C)
        x = shortcut + self.drop_path(x)

        # FFN
        x = x + self.drop_path(self.mlp(self.norm2(x)))

        return x, D_s

    def extra_repr(self) -> str:
        return f"dim={self.dim}, input_resolution={self.input_resolution}, num_heads={self.num_heads}, " \
               f"window_size={self.window_size}, shift_size={self.shift_size}, mlp_ratio={self.mlp_ratio}"

    def flops(self):
        flops = 0
        H, W = self.input_resolution
        # norm1
        flops += self.dim * H * W
        # W-MSA/SW-MSA
        if type(self.window_size) is tuple:
            nW = H * W / self.window_size[0] / self.window_size[1]
            flops += nW * self.attn.flops(self.window_size[0] * self.window_size[1])
        else:
            nW = H * W / self.window_size / self.window_size
            flops += nW * self.attn.flops(self.window_size * self.window_size)
        # mlp
        flops += 2 * H * W * self.dim * self.dim * self.mlp_ratio
        # norm2
        flops += self.dim * H * W
        return flops


class PatchMerging(nn.Module):
    r""" Patch Merging Layer.

    Args:
        input_resolution (tuple[int]): Resolution of input feature.
        dim (int): Number of input channels.
        norm_layer (nn.Module, optional): Normalization layer.  Default: nn.LayerNorm
    """

    def __init__(self, input_resolution, dim, norm_layer=nn.LayerNorm):
        super().__init__()
        self.input_resolution = input_resolution
        self.dim = dim
        self.reduction = nn.Linear(4 * dim, 2 * dim, bias=False)
        self.norm = norm_layer(4 * dim)

    def forward(self, x, D):
        """
        x: B, H*W, C
        D:, B, H, W
        """
        # import pdb;pdb.set_trace()
        H, W = self.input_resolution
        # print(self.input_resolution)
        B, L, C = x.shape
        assert L == H * W, "input feature has wrong size"
        assert H % 2 == 0 and W % 2 == 0, f"x size ({H}*{W}) are not even."

        x = x.view(B, H, W, C)

        if W>=4:
            # import pdb;pdb.set_trace()
            x0 = x[:, :, 0::4, :]  # B H/2 W/2 C
            x1 = x[:, :, 1::4, :]  # B H/2 W/2 C
            x2 = x[:, :, 2::4, :]  # B H/2 W/2 C
            x3 = x[:, :, 3::4, :]  # B H/2 W/2 C
            x = torch.cat([x0, x1, x2, x3], -1)  # B H/2 W/2 4*

            x = x.view(B, -1, 4 * C)  # B H/2*W/2 4*C 

            x = self.norm(x)
            x = self.reduction(x)
            D = D/2
            D0 = D[:, :, 0::4, None]  # B H/2 W/2 C
            D1 = D[:, :, 1::4, None]  # B H/2 W/2 C
            D2 = D[:, :, 2::4, None]  # B H/2 W/2 C
            D3 = D[:, :, 3::4, None]  # B H/2 W/2 C
            D = torch.cat([D0, D1, D2, D3], -1)  # B H/2 W/2 4*C
            D = torch.mean(D, -1)

            return x, D
        elif W<4:
            residue = 4//W            
            x0 = x[:, 0::4, :, :]  # B H/2 W/2 C
            x1 = x[:, 1::4, :, :]  # B H/2 W/2 C
            x2 = x[:, 2::4, :, :]  # B H/2 W/2 C
            x3 = x[:, 3::4, :, :]  # B H/2 W/2 C
            x = torch.cat([x0, x1, x2, x3], -1)  # B H/2 W/2 4*

            x = x.view(B, -1, 4 * C)  # B H/2*W/2 4*C 

            x = self.norm(x)
            x = self.reduction(x)
            D = D/2
            D0 = D[:, 0::4, : None]  # B H/2 W/2 C
            D1 = D[:, 1::4, : None]  # B H/2 W/2 C
            D2 = D[:, 2::4, : None]  # B H/2 W/2 C
            D3 = D[:, 3::4, : None]  # B H/2 W/2 C
            D = torch.cat([D0, D1, D2, D3], -1)  # B H/2 W/2 4*C
            D = torch.mean(D, -1)

            return x, D

    def extra_repr(self) -> str:
        return f"input_resolution={self.input_resolution}, dim={self.dim}"

    def flops(self):
        H, W = self.input_resolution
        flops = H * W * self.dim
        flops += (H // 2) * (W // 2) * 4 * self.dim * 2 * self.dim
        return flops


class BasicLayer(nn.Module):
    """ A basic Swin Transformer layer for one stage.

    Args:
        dim (int): Number of input channels.
        input_resolution (tuple[int]): Input resolution.
        depth (int): Number of blocks.
        num_heads (int): Number of attention heads.
        window_size (int): Local window size.
        mlp_ratio (float): Ratio of mlp hidden dim to embedding dim.
        qkv_bias (bool, optional): If True, add a learnable bias to query, key, value. Default: True
        qk_scale (float | None, optional): Override default qk scale of head_dim ** -0.5 if set.
        drop (float, optional): Dropout rate. Default: 0.0
        attn_drop (float, optional): Attention dropout rate. Default: 0.0
        drop_path (float | tuple[float], optional): Stochastic depth rate. Default: 0.0
        norm_layer (nn.Module, optional): Normalization layer. Default: nn.LayerNorm
        downsample (nn.Module | None, optional): Downsample layer at the end of the layer. Default: None
        use_checkpoint (bool): Whether to use checkpointing to save memory. Default: False.
    """

    def __init__(self, dim, input_resolution, patch_size, depth, num_heads, window_size,
                 mlp_ratio=4., qkv_bias=True, qk_scale=None, drop=0., attn_drop=0.,
                 drop_path=0., norm_layer=nn.LayerNorm, downsample=None, use_checkpoint=False):
        
        super().__init__()
        self.dim = dim
        self.input_resolution = input_resolution
        self.depth = depth
        self.use_checkpoint = use_checkpoint
        self.patch_size = patch_size
        # print("Basic_Layer", input_resolution)
        # print("Basic Layer", window_size)
        # build blocks
        self.blocks = nn.ModuleList([
            SwinTransformerBlock(dim=dim, patch_size=patch_size, input_resolution=input_resolution,
                                 num_heads=num_heads, window_size=window_size,
                                 shift_size=(0, 0) if (i % 2 == 0) else (window_size[0], window_size[1] // 4) if (input_resolution[1] >= 4) else (window_size[1]//4, window_size[0]), 
                                 mlp_ratio=mlp_ratio,
                                 qkv_bias=qkv_bias, qk_scale=qk_scale,
                                 drop=drop, attn_drop=attn_drop,
                                 drop_path=drop_path[i] if isinstance(drop_path, list) else drop_path,
                                 norm_layer=norm_layer)
            for i in range(depth)])

        # patch merging layer
        if downsample is not None:
            self.downsample = downsample(input_resolution, dim=dim, norm_layer=norm_layer)
        else:
            self.downsample = None

    def forward(self, x, D_s, theta_max):
        # print("basic layer")
        # import pdb;pdb.set_trace()
        for blk in self.blocks:
            if self.use_checkpoint:
                x = checkpoint.checkpoint(blk, x, theta_max)
            else:
                x, D = blk(x, D_s, theta_max)
        if self.downsample is not None:
            x_down, D_down = self.downsample(x, D)
            return x, D, x_down, D_down
        else:
            return x, D, x, D

    def extra_repr(self) -> str:
        return f"dim={self.dim}, input_resolution={self.input_resolution}, depth={self.depth}"

    def flops(self):
        flops = 0
        for blk in self.blocks:
            flops += blk.flops()
        if self.downsample is not None:
            flops += self.downsample.flops()
        return flops


class PatchEmbed(nn.Module):
    r""" Image to Patch Embedding

    Args:
        img_size (int): Image size.  Default: 224.
        patch_size (int): Patch token size. Default: 4.
        in_chans (int): Number of input image channels. Default: 3.
        embed_dim (int): Number of linear projection output channels. Default: 96.
        norm_layer (nn.Module, optional): Normalization layer. Default: None
    """

    def __init__(self, img_size=224, distortion_model = 'spherical', radius_cuts=16, azimuth_cuts=64, radius=None, azimuth=None, in_chans=3, embed_dim=96, n_radius = 10, n_azimuth=10, norm_layer=None):
        super().__init__()
        img_size = to_2tuple(img_size)

        #number of MLPs is number of patches
        #patch_size if needed
        patches_resolution = [radius_cuts, azimuth_cuts]  ### azimuth is always cut in even partition 
        self.azimuth_cuts = azimuth_cuts
        self.radius_cuts = radius_cuts
        self.subdiv = (self.radius_cuts, self.azimuth_cuts)
        self.img_size = img_size
        self.distoriton_model = distortion_model
        self.radius = radius
        self.azimuth = azimuth
        # self.measurement = 1.0
        self.max_azimuth = np.pi*2
        patch_size = [self.img_size[0]/(2*radius_cuts), self.max_azimuth/azimuth_cuts]
        # self.azimuth = 2*np.pi  comes from the cartesian script

        
        self.patch_size = patch_size
        self.patches_resolution = patches_resolution
        self.num_patches = radius_cuts*azimuth_cuts
        self.in_chans = in_chans
        self.embed_dim = embed_dim

        
        # subdiv = 3
        self.n_radius = n_radius
        self.n_azimuth = n_azimuth
        self.mlp = nn.Linear(self.n_radius*self.n_azimuth*in_chans, embed_dim)

        if norm_layer is not None:
            self.norm = norm_layer(embed_dim)
        else:
            self.norm = None

    def forward(self, x, dist):
        B, C, H, W = x.shape

        dist = dist.transpose(1,0)
        radius_buffer, azimuth_buffer = 0, 0
        params, D_s, theta_max = get_sample_params_from_subdiv(
            subdiv=self.subdiv,
            img_size=self.img_size,
            distortion_model = self.distoriton_model,
            D = dist, 
            n_radius=self.n_radius,
            n_azimuth=self.n_azimuth,
            radius_buffer=radius_buffer,
            azimuth_buffer=azimuth_buffer)

        # import pdb;pdb.set_trace()
        sample_locations = get_sample_locations(**params)  ## B, azimuth_cuts*radius_cuts, n_radius*n_azimut
        B, n_p, n_s = sample_locations[0].shape
        x_ = sample_locations[0].reshape(B, n_p, n_s, 1).float()
        x_ = x_/(H//2)
        y_ = sample_locations[1].reshape(B, n_p, n_s, 1).float()
        y_ = y_/(W//2)
        out = torch.cat((y_, x_), dim = 3)
        out = out.cuda()
        # print(out.shape)

        # FIXME look at relaxing size constraints
        # assert H == self.img_size[0] and W == self.img_size[1], \
        #     f"Input image size ({H}*{W}) doesn't match model ({self.img_size[0]}*{self.img_size[1]})."

        ############################ projection layer ################
        x_out = torch.empty(B, self.embed_dim, self.radius_cuts, self.azimuth_cuts).cuda(non_blocking=True)

        tensor = nn.functional.grid_sample(x, out, align_corners = True).permute(0,2,1,3).contiguous().view(-1, self.n_radius*self.n_azimuth*self.in_chans)

        # tensor = x[:, :, self.x_[i*self.radius_cuts:self.radius_cuts + i*self.radius_cuts], self.y_[i*self.radius_cuts:self.radius_cuts + i*self.radius_cuts]].permute(0,2,1,3).contiguous().view(-1, self.n_radius*self.n_azimuth*self.in_chans)
        out_ = self.mlp(tensor)
        out_ = out_.contiguous().view(B, self.radius_cuts*self.azimuth_cuts, -1)   # (B, 1024, embed_dim)


        out_up  = out_.reshape(B, self.azimuth_cuts, self.radius_cuts, self.embed_dim)  ### check the output dimenssion properly

        # out_up = torch.flip(out_up, [1])  # (B,  az_div/2, rad_div, embed dim)
        out_up = out_up.transpose(1, 3)
        # out_down = out_down.transpose(1,3)
        x_out[:, :, :self.radius_cuts, :] = out_up

        x = x_out.flatten(2).transpose(1, 2)  # B Ph*Pw C

        if self.norm is not None:
            x = self.norm(x)
        return x, D_s, theta_max

    def flops(self):
        Ho, Wo = self.patches_resolution
        flops = Ho * Wo * self.embed_dim * self.in_chans * (self.patch_size[0] * self.patch_size[1])
        if self.norm is not None:
            flops += Ho * Wo * self.embed_dim
        return flops

@BACKBONES.register_module()
class SwinTransformerAng(nn.Module):
    r""" Swin Transformer
        A PyTorch impl of : `Swin Transformer: Hierarchical Vision Transformer using Shifted Windows`  -
          https://arxiv.org/pdf/2103.14030

    Args:
        img_size (int | tuple(int)): Input image size. Default 224
        patch_size (int | tuple(int)): Patch size. Default: 4
        in_chans (int): Number of input image channels. Default: 3
        num_classes (int): Number of classes for classification head. Default: 1000
        embed_dim (int): Patch embedding dimension. Default: 96
        depths (tuple(int)): Depth of each Swin Transformer layer.
        num_heads (tuple(int)): Number of attention heads in different layers.
        window_size (int): Window size. Default: 7
        mlp_ratio (float): Ratio of mlp hidden dim to embedding dim. Default: 4
        qkv_bias (bool): If True, add a learnable bias to query, key, value. Default: True
        qk_scale (float): Override default qk scale of head_dim ** -0.5 if set. Default: None
        drop_rate (float): Dropout rate. Default: 0
        attn_drop_rate (float): Attention dropout rate. Default: 0
        drop_path_rate (float): Stochastic depth rate. Default: 0.1
        norm_layer (nn.Module): Normalization layer. Default: nn.LayerNorm.
        ape (bool): If True, add absolute position embedding to the patch embedding. Default: False
        patch_norm (bool): If True, add normalization after patch embedding. Default: True
        use_checkpoint (bool): Whether to use checkpointing to save memory. Default: False
    """

    def __init__(self, img_size=224, radius_cuts=16, azimuth_cuts = 64, in_chans=3, num_classes=1000,
                 embed_dim=96, depths=[2, 2, 6, 2], num_heads=[3, 6, 12, 24],
                 window_size=7, mlp_ratio=4., qkv_bias=True, qk_scale=None,
                 drop_rate=0., attn_drop_rate=0., drop_path_rate=0.1,
                 norm_layer=nn.LayerNorm, ape=False, out_indices=(0, 1, 2, 3), patch_norm=True,
                 use_checkpoint=False, distortion_model = 'spherical',n_radius=10, n_azimuth=10, **kwargs):
        super().__init__()

        self.num_classes = num_classes
        self.num_layers = len(depths)
        self.embed_dim = embed_dim
        self.ape = ape
        self.out_indices = out_indices
        self.patch_norm = patch_norm
        num_features = [int(embed_dim * 2 ** i) for i in range(self.num_layers)]
        self.num_features = num_features
        self.mlp_ratio = mlp_ratio
        self.minputsz = img_size
        # self.masks = masks 
        # 
        # self.dim_out_in = dim_out_in

        res=1024

        cartesian = torch.cartesian_prod(
            torch.linspace(-1, 1, res),
            torch.linspace(1, -1, res)
        ).reshape(res, res, 2).transpose(2, 1).transpose(1, 0).transpose(1, 2)
        radius = cartesian.norm(dim=0)
        y = cartesian[1]
        x = cartesian[0]
        theta = torch.atan2(cartesian[1], cartesian[0])
        # split image into non-overlapping patches
        self.patch_embed = PatchEmbed(
            img_size=img_size, distortion_model = distortion_model, radius_cuts=radius_cuts, azimuth_cuts= azimuth_cuts,  radius = radius, azimuth = theta, in_chans=in_chans, embed_dim=embed_dim,n_radius=n_radius, n_azimuth=n_azimuth,
            norm_layer=norm_layer if self.patch_norm else None)
        num_patches = self.patch_embed.num_patches
        patches_resolution = self.patch_embed.patches_resolution 
        self.patches_resolution = patches_resolution ### need to calculate FLOPS ( use later )
        patch_size = self.patch_embed.patch_size
        # absolute position embedding
        if self.ape:
            self.absolute_pos_embed = nn.Parameter(torch.zeros(1, num_patches, embed_dim))
            trunc_normal_(self.absolute_pos_embed, std=.02)

        self.pos_drop = nn.Dropout(p=drop_rate)

        # stochastic depth
        dpr = [x.item() for x in torch.linspace(0, drop_path_rate, sum(depths))]  # stochastic depth decay rule
        # import pdb;pdb.set_trace()
        # build layers
        self.layers = nn.ModuleList()
        for i_layer in range(self.num_layers):
            layer = BasicLayer(dim=int(embed_dim * 2 ** i_layer),
                               input_resolution=(patches_resolution[0] // (1 ** i_layer),
                                                 patches_resolution[1] // (4 ** i_layer)),
                                patch_size = patch_size,
                               depth=depths[i_layer],
                               num_heads=num_heads[i_layer],
                               window_size=window_size,
                               mlp_ratio=self.mlp_ratio,
                               qkv_bias=qkv_bias, qk_scale=qk_scale,
                               drop=drop_rate, attn_drop=attn_drop_rate,
                               drop_path=dpr[sum(depths[:i_layer]):sum(depths[:i_layer + 1])],
                               norm_layer=norm_layer,
                               downsample=PatchMerging if (i_layer < self.num_layers - 1) else None,
                               use_checkpoint=use_checkpoint)
            self.layers.append(layer)

        # add a norm layer for each output
        for i_layer in out_indices:
            layer = norm_layer(num_features[i_layer])
            layer_name = f'norm{i_layer}'
            self.add_module(layer_name, layer)

    def init_weights(self, pretrained=None):
        """Initialize the weights in backbone.

        Args:
            pretrained (str, optional): Path to pre-trained weights.
                Defaults to None.
        """

        def _init_weights(m):
            if isinstance(m, nn.Linear):
                trunc_normal_(m.weight, std=.02)
                if isinstance(m, nn.Linear) and m.bias is not None:
                    nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.LayerNorm):
                nn.init.constant_(m.bias, 0)
                nn.init.constant_(m.weight, 1.0)

        if isinstance(pretrained, str):
            self.apply(_init_weights)
            logger = get_root_logger()
            load_checkpoint(self, pretrained, strict=False, logger=logger)
        elif pretrained is None:
            self.apply(_init_weights)
        else:
            raise TypeError('pretrained must be a str or None')

    @torch.jit.ignore
    def no_weight_decay(self):
        return {'absolute_pos_embed'}

    @torch.jit.ignore
    def no_weight_decay_keywords(self):
        return {'relative_position_bias_table'}

    def forward(self, x):
        x = x[0:1,:,:,:]
        dist = torch.tensor(np.array([0.5, 0.5, 0.5, 0.5]).reshape(1, 4)).float().cuda()
        x, D_s, theta_max = self.patch_embed(x, dist)

        if self.ape:
            x = x + self.absolute_pos_embed
        x = self.pos_drop(x)

        outs = []
        for i in range(self.num_layers):
            layer = self.layers[i]
            x_out, D_out, x, D_s,  = layer(x, D_s, theta_max)
            if i in self.out_indices:
                norm_layer = getattr(self, f'norm{i}')
                x_out = norm_layer(x_out)
                # import pdb;pdb.set_trace()
                out = x_out.view(-1, int(math.sqrt(x_out.size(1))), int(math.sqrt(x_out.size(1))), self.num_features[i]).permute(0, 3, 1, 2).contiguous()
                out = torch.cat((out, out), axis=0)
                outs.append(out)
        return tuple(outs)

    def flops(self):
        flops = 0
        flops += self.patch_embed.flops()
        for i, layer in enumerate(self.layers):
            flops += layer.flops()
        flops += self.num_features * self.patches_resolution[0] * self.patches_resolution[1] // (2 ** self.num_layers)
        flops += self.num_features * self.num_classes
        return flops

if __name__=='__main__':
    model = SwinTransformerAng(img_size=64,
                        radius_cuts=16, 
                        azimuth_cuts=64,
                        in_chans=3,
                        num_classes=200,
                        embed_dim=96,
                        depths=[2, 2, 18, 2],
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
                        n_radius = 10,
                        n_azimuth = 10)
    model = model.cuda()
    

    t = torch.ones(1, 3, 64, 64).float().cuda()
    dist = torch.tensor(np.array([0.5, 0.5, 0.5, 0.5]).reshape(1, 4)).float().cuda()

    m = model(t, dist)
    breakpoint()
    print("ass")
    # import pdb;pdb.set_trace()