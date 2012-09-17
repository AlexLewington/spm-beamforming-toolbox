function res = bf_write_nifti(BF, S)
% Writes out nifti images of beamformer results
% Copyright (C) 2012 Wellcome Trust Centre for Neuroimaging

% Vladimir Litvak
% $Id$

%--------------------------------------------------------------------------
if nargin == 0
    normalise         = cfg_menu;
    normalise.tag     = 'normalise';
    normalise.name    = 'Global normalisation';
    normalise.help    = {'Normalise image values by the mean'};
    normalise.labels  = {
        'No'
        'Each image separately'
        'Across images'
        }';
    normalise.values  = {
        'no'
        'separate'
        'all'
        }';
    normalise.val = {'separate'};
    
    space         = cfg_menu;
    space.tag     = 'space';
    space.name    = 'Image space';
    space.help    = {'Specify image space'};
    space.labels  = {
        'MNI'
        'Native'
        'MNI-aligned'
        }';
    space.values  = {
        'mni'
        'native'
        'aligned'
        }';
    space.val = {'mni'};
    
    nifti      = cfg_branch;
    nifti.tag  = 'nifti';
    nifti.name = 'NIfTI';
    nifti.val  = {normalise, space};
    
    res = nifti;
    
    return
elseif nargin < 2
    error('Two input arguments are required');
end

source     = BF.sources.grid;
source.pos   = BF.sources.pos;

switch S.space
    case 'mni'
        sMRI   = fullfile(spm('dir'), 'canonical', 'single_subj_T1.nii');
        source = ft_transform_geometry(BF.data.transforms.toMNI, source);
    case 'aligned'
        source = ft_transform_geometry(BF.data.transforms.toMNI_aligned, source);
        sMRI   = fullfile(spm('dir'), 'canonical', 'single_subj_T1.nii');
    case 'native'
        source = ft_transform_geometry(BF.data.transforms.toNative, source);
        sMRI   = BF.data.mesh.sMRI;
end

scale = ones(1, numel(BF.output.image));
switch S.normalise
    case  'separate'
        for i = 1:numel(BF.output.image)
            val = BF.output.image(i).val;
            scale(i) = 1./mean(val(~isnan(val)));
        end
    case  'all'
        val = spm_vec({BF.output.image(:).val});
        scale = scale./mean(val(~isnan(val)));
end


outvol = spm_vol(sMRI);
%
outvol.dt(1) = spm_type('float32');


nimages = numel(BF.output.image);

cfg = [];
cfg.parameter = 'pow';
cfg.downsample = 1;
cfg.showcallinfo = 'no';

spm('Pointer', 'Watch');drawnow;
spm_progress_bar('Init', nimages , 'Writing out images'); drawnow;
if nimages  > 100, Ibar = floor(linspace(1, nimages ,100));
else Ibar = 1:nimages; end


for i = 1:nimages
    source.pow = scale(i)*BF.output.image(i).val;
    sourceint = ft_sourceinterpolate(cfg, source, ft_read_mri(sMRI, 'format', 'nifti_spm'));
    
    outvol.fname= fullfile(pwd, [BF.output.image(i).label '.nii']);
    outvol = spm_create_vol(outvol);
    spm_write_vol(outvol, sourceint.pow);
    
    nifti.files{i, 1} = outvol.fname;
    
    if ismember(i, Ibar)
        spm_progress_bar('Set', i); drawnow;
    end
end

spm_progress_bar('Clear');

res = nifti;
