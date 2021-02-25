#!/bin/bash

# push public rural data portal data to public dropbox folder.
# note: this only makes sense (1) on Polaris and (2) if you have Rclone configured properly.
# output folder: https://www.dropbox.com/sh/pjdxjqj1afrur6u/AADNODZvC6UFDFX4SMXUM2a6a?dl=0

# tar up the DTAs
tar -C ~/iec/rural_platform/ -czvf ~/secc/frozen_data/rural_platform/rural_data.tar.gz shrid_data.dta district_data.dta canal_data.dta

# push to the public data folder
rclone copy ~/secc/frozen_data/rural_platform/rural_data.tar.gz my_remote:SamPaul/rural_data
