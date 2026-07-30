
# Download treehub from https://doi.org/10.57760/sciencedb.23014
# Move it to some working directory and unzip,
# then change to the treehub directory
cd ~/databases/TreeHub/test1/TreeHub_json-zip_20250331/

# Get perl script from https://github.com/dchesters/treehub
# and move it to the working directory
#
# Download NCBI taxonomy (taxdump.tar.gz) from https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/
# Unzip the object, there are several files in there, only one is needed, 
# copy names.dmp into the working directory
#
# Get COL database (base release, text tree) from https://www.catalogueoflife.org/data/download
# Move to working directory and unzip. It is a single file, write the file name into the following.

catalogue_of_life_path=dataset-315777.txtree
ncbi_tax_database_path=names.dmp
treehub_treejson_path=tree.json
treehub_paperjson_path=paper.json
treehub_newick_path=./tree/out/
perl parse_treehub.pl $catalogue_of_life_path $ncbi_tax_database_path $treehub_treejson_path $treehub_paperjson_path $treehub_newick_path


# References
#   Ruggiero et al. (2015) A Higher Level Classification of All Living Organisms. PLoS ONE, 10, e0119248.
#   Schoch et al. (2020) NCBI Taxonomy: a comprehensive update on curation, resources and tools. Database, baaa062.
#   Wu et al. (2025) TreeHub: a comprehensive dataset of phylogenetic trees. Sci Data 12, 924.
#   Wu and Wu (2025) Science Data Bank. https://doi.org/10.57760/sciencedb.23014

