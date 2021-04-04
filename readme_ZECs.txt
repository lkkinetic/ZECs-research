%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read Me for Adler and Kiesling "The Effect of Zero Emission Credits in      %
% Illinois and New York on Wholesale Power Market and Environmental Outcomes" %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

This readme lists and summarizes the Stata .do files used to prepare the data and
perform the analyses in "The Effect of Zero Emission Credits in Illinois and New 
York on Wholesale Power Market and Environmental Outcomes." The following .do 
files can be found in the publicly available Github repository:

Please see this .do file first:
-packages_to_install.do: Contains a list of several packages used throughout the
remaining .do files.  You will need to install these packages if you have not used
them in your Stata previously to run the remaining files.

After reviewing the above:
-The Day-Ahead (DA) LMP data by ISO/RTO -- ERCOT, ISO-NE, MISO, NYISO, PJM,
and SPP -- each is processed with a separate .do file in the appropriately 
named folder.  In each folder is a .txt file that lists the location where the 
publicly available data can be downloaded. The processed Stata datasets for each 
can be found in the intermediate folder within each to allow the code for the 
analyses to run; if you wish to re-run the processing simply copy the raw, unzipped
files to the inputs folder within the appropriate ISO/RTO folder.

-The daily data on ambient air quality comes from EPA's AQS AirData database, with 
data files downloaded from:
https://aqs.epa.gov/aqsweb/airdata/download_files.html#Daily
The data is processed in separate subfolders within the EPA AQS folder for each 
criteria air pollutant. The processed Stata datasets can be found in the output 
folder within each subfolder in order to run the analyses in AQS_DiD.do; if you
wish to re-run the processing simply copy the raw, unzipped files to the inputs
folder within the appropriate pollutant's folder.

Finally, the main .do files for the remaining data processing and analyses:
- EIA_MISO_PJM_processing.do: Combines the processed data from EIA-923 with the
LMP data for MISO and PJM to create the main dataset for our analyses of net 
generation. Data from EIA-923 was processed and used in "Considering the Nuclear
Option: Hidden Benefits and Social Costs of Nuclear Power in the U.S. since 1970"
(Adler, Jha, and Severnini, 2020).
- ZEC_DiD.do: Utilizes the processed EIA-923 data to perform the difference-
in-difference (DiD) analyses of net generation presented in the main paper and 
the appendix.
- AQS_DiD.do: Merges together the state-month level data from EPA's AQS Data
Mart for PM2.5, SO2, and NO2 and performs the DiD analyses of ambient air quality
presented in the main paper and the appendix.
- LMP_data_all.do: Collapses the ISO/RTO LMP data processed separately to the 
state-month level and merges together into a single dataset.  Then, performs the 
DiD analyses of wholesale prices presented in the main paper and the appendix.
- EIA_861_processing_analysis.do: Processes the raw EIA-861 data on monthly 
retail prices by sector and state.  Then, performs the DiD analyses of retail
prices presented in the main paper and the appendix.
- Parallel_trends_check.do: Utilizing the data processed in the other .do files,
this .do file prepares a series of graphs presented in the Appendix showing the 
raw trends in the monthly data across our outcomes of interest.
- CEMS\CEMS_quarterly_10_19.do: Processes raw, quarterly data files (2010-2019) 
from EPA's CEMS database on daily-level emissions to get state-month level 
average emissions. Then, performs the DiD analyses of CO2 emissions presented 
in the main paper and the appendix. Due to file size, the processed dataset is
zipped in the CEMS\intermediate folder.
