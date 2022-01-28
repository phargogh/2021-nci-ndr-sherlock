This directory is for a request from Rafa to re-run some of Ginger's scripts
relating to Nitrate outputs from him and Ian.

> Ian has now completed the runs of the RF-model to translate N-exports to surface and groundwater concentrations. Now, we need to run the part of the pipeline which combines those two metrics into estimates of N-concentration in drinking water for each scenario – based on country level stats of drinking water sources (i.e., splits between surface and groundwater in a country’s drinking water supply).
>
> Have you seen this step in the pipeline we inherited from Ginger and might you be able to take over that step? I am also very happy to help figuring out where that part of the analysis scripts are located.
>
> As soon as we have the drinking water rasters for the different scenarios, we need to rerun the optimization with the added drinking water objective. For that, we need to sync with Peter who will actually do that. At some point we had discussed that this could be possibly done as part of your work on the pipeline and on Sherlock but I am not sure if we need to understand first if adding an objective will require some reworking of the code or will work out of the box.

Later on in another email, Rafa says:

> I believe the code that does this conversion lives here: https://github.com/vakowal/nci_ndr/blob/master/predict_noxn_and_endpoints.py lines 145 -169 to create a raster which defines the fraction of surface water in each pixel’s drinking water (as a function of the country in which a country is located). The fraction of groundwater in that pixel’s drinking water is than 1-that_value.
Based on that, the actual concentration is calculated in lines 198-229.


Contents of this directory:

* `nci_ndr`
  This is a git submodule pointing to Ginger's `nci_ndr` repo.  The submodule
  state is not automatically initialized when this repo is cloned, so remember
  to `git submodule init` when needing to re-run things.

* `data-from-rafa`
