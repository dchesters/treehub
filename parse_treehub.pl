
# 
# 
# 
# 
# 
# DETAILS
# 	In the comments herein you will see a lot of tree IDs in the format T[number].nwk,
# 	these are examples for treehub filenames containing trees matching patterns (regexes). 
# 	Herein are a load of patterns with the primary aim of reading taxon names from terminal IDs
# 	(otherwise barely scratching the surface of processing tasks),
# 	and gives some idea of the processing that should have been conducted by treehub in order to present usable data.
# 	If you want this script to do anything, 
#		then you will need to give the paths to the relevent files on your system, see first set of variables just below.
# 
# 
# 
# 
# 
# CHANGE LOG
# 2026-03-29: 	Started.
# 2026-07-09: 	After manuscript review, conducting further developments to give more detailed description of TreeHub.
# 2026-07-15:	Incorporated attempted taxonomic mapping of taxon-like words parsed from terminal IDs
# 
# 
# 
# 
# 
# 
# 
# 
# 
#############################################################################################################################





# in following 2 variables give paths to the taxonomic databases
$ncbi_tax_database_path 	= "/home/douglas/databases/NCBI_taxonomy/2023Jan/names.dmp";
$catalogue_of_life_path 	= "/home/douglas/databases/Taxonomy/Catalogue_of_Life/38ec8244-5887-4f0f-b923-56f8cb015c19/dataset-9923.txt";


$treehub_treejson_path 		= "/home/douglas/databases/TreeHub/TreeHub_json-zip_20250331/tree.json";
$treehub_paperjson_path 	= "/home/douglas/databases/TreeHub/TreeHub_json-zip_20250331/paper.json";
$treehub_newick_path 		= "/home/douglas/databases/TreeHub/TreeHub_json-zip_20250331/tree/out/";


# probably not needed:
$duplicates_path 		= "/home/douglas/databases/TreeHub/duplicates.txt";




#############################################################################################################################
# 

# primary task is describing the trees, which is the default option. 
# there is also the means to read other aspects of treehub, not run by default.
$parse_treefiles_only = 1;
if($parse_treefiles_only == 1)
	{

	# Read taxonomic names from 2 databases. 
	# NCBI is included as favored by informaticians, names also read from COL which is the most comprehensive.
	parse_ncbi_tax_database();
	parse_catalogue_of_life();

	# this file produced by $parse_treefiles_only = 0, ignored if not in working directory
	read_treetypes();

	parse_treefiles();

	exit;
	};








##########################################################################################################################
##########################################################################################################################
##########################################################################################################################


 # nb this section not run under default option.


# metadata is in 2 different files, read first one
$treejson_entries=0;
$max_tree_count=0;$max_tree_count_study;
open(IN1, "$treehub_treejson_path") || die "\nerror 79, cant open:$treehub_treejson_path.\n";
while(my $line = <IN1>)
  {
  # json entries delimited with curly braces
  if($line =~ /^\s\}/) 
    	{
	my $study_ID="";
	if($json_section =~ /\"study_id\"\: (\d+)\,/){$study_ID=$1}else{print "warning, cant parse study ID:$json_section\n"};
	my $tree_type="";

	#  "tree_type_new": "treebase",
	if($json_section =~ /\"tree_type_new\"\: \"(\w+)/){$tree_type=$1}else{print "error json_section:$json_section\n"};

	$type_of_study{$study_ID}=$tree_type;
	parse_entry($json_section);
	$json_section=""; $treejson_entries++;
    	}else{
    	$json_section .= $line;
    	};
  };
close IN1;

print "\ntreejson_entries:$treejson_entries
none:$none
crawl:$crawl
treebase:$treebase
\n";


my @study_IDs = keys %type_of_study;
foreach my $studyID(@study_IDs){my $studytype = $type_of_study{$studyID}; $study_types{$studytype}++};
my @types = keys %study_types;
foreach my $studytype(@types){print "$studytype:$study_types{$studytype}\n"};


# about 240 title fields blank, many in abstract field instead
$json_entries=0;
$max_tree_count=0;$max_tree_count_study;
open(IN, "$treehub_paperjson_path") || die "\nerror 115, cant open $treehub_paperjson_path.\n";
open(OUT_TABLE, ">study_details_parsed.tdt") || die "\nerror 116\n";
while(my $line = <IN>)
  {
  if($line =~ /^\s\}/)
    	{
	parse_entry($json_section);$json_section="";$json_entries++;
    	}else{
    	$json_section .= $line;
    	};
  };
close IN;
close OUT_TABLE;






###########################################################################################################################################
###########################################################################################################################################


sub parse_entry
{
my $entry = shift; # print "entry:$entry\n"; die "";

my $study_id;
if($entry =~ /\"study_id\"\: ([0-9]+)\,/)
	{$study_id = $1}else{};

# parse tree IDs first
my $nwk_count=0;
my @current_study_treeIDs=();
while($entry =~ s/\"(T\d+\.nwk)\"\,*//)
	{
	my $treeID = $1;push @current_study_treeIDs, $treeID;
	if (-e "$treehub_newick_path$treeID") {
	$nwk_found++; # print "File exists!\n";
	$treeID_from_study{$treeID} = $study_id;
	} else {
	$nwk_missing++; # print "File does not exist:$treeID\n";
	}
	$nwk_count++;
	};
if($nwk_count >= $max_tree_count){$max_tree_count=$nwk_count;$max_tree_count_study=$study_id};

# note studies with very large number of trees:
if($nwk_count >= 5000)
	{print "tree count $nwk_count, for study $study_id\n"}

my $year;
if($entry =~ /\"year\"\: ([12][90][0-9]{2})\,/)
	{
	$year = $1;$years{$year}++;
	}elsif($entry =~ /\"year\"/)
	{die "\nerror 63\n"
	};
$studytype="NA";
if($type_of_study{$study_id} =~ /\w/)
	{$studytype=$type_of_study{$study_id}};
$type_by_year{$year}{$studytype}++;
$type_by_paperjson_study{$studytype}++;

my $current_study_legacyID = "NA";

# minimum journal name length is 3 characters
if($entry =~ /\"journal\"\:\s+\"([^\"]{3,})\"/)
	{
	my $journal=$1;	$all_journals{$journal}++;
	if($entry =~ /dryad/){$classes{dryad}{$year}++};

	}elsif($entry =~ /\"doi\:([0-9\.]+\/dryad\.[0-9a-z]+)\"/) # this finds all entries with string 'dryad'
	{
	my $dryad_doi = $1;$dryad_dois++; # print "dryad_doi:$dryad_doi\n";
	$classes{dryad}{$year}++;
	}elsif($entry =~ /\"doi\"\: \"(https\:..doi.org\/[0-9\.]+\/zenodo.\d+)\"/)
	{
	my $zenodo_doi = $1;$zenodo_dois++;

	}elsif($entry =~ / \"legacy_id\"\: \"(S.+)\"/)
	{
	my $legacyID = $1; # from dates these must be treebase; not many of these (not to be used for counting treebase); 
	$treebase++;$current_study_legacyID = $legacyID;
	}elsif($entry =~ /\"(doi\:\d+\.\d+\/.+)\"/)
	{
	my $doi = $1; # not many of these, couple i checked were dryad
	$dryad_dois++;
	}elsif($entry =~ /./)
	{
#	print "ENTRY$entry\n";
	}elsif($entry =~ /doi\"\: \"https\:(.+)/)
	{
	my $link = $1;
	# journal name missing, though link might indicate
	# print "\nmissing journal, check: $link\n";
	# very few of these, and journals already in list.
	};

	# "title": "
	if($line =~ /\"title\"\: \"([A-Z].+)/)
		{
		my $title = $1;
		$titles++;
		if($store_titles{$title}==1){$title_duplicates++};
		$store_titles{$title}=1;
		}elsif($line =~ /\"title\"\:/)
		{
	#	print "$line";
		}

# @current_study_treeIDs
# $current_study_legacyID

for my $each_tree_current_study(@current_study_treeIDs)
	{print OUT_TABLE "$each_tree_current_study\t$study_id\t$studytype\t$current_study_legacyID\n"};


if($json_entries =~ /000$/){print "json_entries:$json_entries\n"};
}; # sub parse_entry

###########################################################################################################################################
###########################################################################################################################################





@journal_keys = keys %all_journals; @journal_keys = sort @journal_keys;
@years_observed = keys %years;@years_observed = sort { $a <=> $b } @years_observed;
foreach my $year(@years_observed)
	{
#	print "$year\t$years{$year}\t$classes{dryad}{$year}\tTB:$type_by_year{$year}{treebase}\tCR:$type_by_year{$year}{crawl}\tNA:$type_by_year{$year}{NA}\n";
	};


print "
json_entries:$json_entries
journals:$#journal_keys
titles:$titles
title_duplicates:$title_duplicates
dryad_dois:$dryad_dois
zenodo_dois:$zenodo_dois
max_tree_count:$max_tree_count ($max_tree_count_study)
treebase:$treebase
nwk_found:$nwk_found
nwk_missing:$nwk_missing
";

foreach my $journal(@journal_keys)
{
# print "$journal\n";
};

print "TB:$type_by_paperjson_study{treebase}\n";
print "CR:$type_by_paperjson_study{crawl}\n";
print "NA:$type_by_paperjson_study{NA}\n";



open(IN2, $duplicates_path) || die "\nerror 143.\n";
print "\nreading duplicates file\n";
while(my $line = <IN2>)
	{
	
# ./T00004115.nwk ./T00004118.nwk
	$line =~ s/\n//;$line =~ s/\r//;
	if($line =~ /\.\/(\S+)\s+\.\/(\S+)/)
		{
		my $ID1 = $1; my $ID2 = $2;$duplicate_pair_parsed++;

if($treeID_from_study{$ID1} eq  $treeID_from_study{$ID2})
	{
	# identical pair from same study, presumably bootstrap replicate, ignore
	}else{
	$potential_duplicates++;
	# print "identical tree pair from different studies:$ID1 ($treeID_from_study{$ID1}) $ID2 ($treeID_from_study{$ID2})\n";
	$studies_with_dupliactes{$treeID_from_study{$ID1}}=1;$studies_with_dupliactes{$treeID_from_study{$ID2}}=1;
	};

		};
	};
close IN2;

@dups = keys %studies_with_dupliactes;

print "
duplicate_pair_parsed:$duplicate_pair_parsed
potential_duplicates:$potential_duplicates
studies with duplciates:$#dups

FIN.
\n";

exit;




##########################################################################################################################
##########################################################################################################################
##########################################################################################################################



  # read all treefiles of treehub, and try to figure out what they contain.



sub parse_treefiles
{
print "\nreading treefiles only\n";

# Folder containing tree files is ./TreeHub_json-zip_20250331/tree/out/
@file_list = glob './TreeHub_json-zip_20250331/tree/out/*';
print "total file count:", scalar @file_list , "\n";
foreach my $file(@file_list)
	{
	my $filename_only = $file;if($filename_only =~ s/.+\/(T\d+\.nwk)/$1/){}else{die "\nerror 357, unexpected path:$file \n"};

	# Count empty files
	my $size = -s $file;

	# list files to skip here, e.g. T00119789 contains dna sequences as terminal IDs and crashes script
	if($file =~ /T00119789.nwk/){$size = 0};

	if($size == 0)
	{
	$empty_files++
	}else{


	# Read current file into variable $contents.
	open FILE,$file or die "Error.\n";my $contents=<FILE>;close FILE;


	my $newick_delimitor=0;while($contents =~ s/\;//){$newick_delimitor++};
	if($newick_delimitor==1){$single_newicks++}elsif($newick_delimitor==0){$zero_newicks++}elsif($newick_delimitor>1){$multiple_newicks++};
	if($newick_delimitor==1)
	{ # virtually all non empty files have single newick
	if($contents =~ /NEXUS/){$nexus_files++};
	# Old way to denote tree is rooted/unrooted. Usually immediately before tree string. rare in Newick.
	if($contents =~ s/^\[\&[RU]\]\s*//)
		{$root_status++}elsif($contents =~ /\[\&.+\]/){die "\nerror 292:$contents\n"}else{$no_root_status++};


	if($contents =~ /\(.*\(.*\).*\)/)
		{
		# Current treefile contains nested parentheses.
		$parentheses++;
		my $mapped_tax_current_tree =0;my $mapped_tax_current_tree2 =0;

		if($contents =~ /Neptune2_ex_Reniera/)
			{
			print "file:$file contents:$contents\n";
			};


		##########################################################################################################################
		##########################################################################################################################
		##########################################################################################################################


		# check if current tree contains treehub convention label quoting
		if($contents =~ /\'\\\'.+\\\'\'/)
			{
			$trees_treehub_quoted++;
			}elsif($contents =~ /\'.+\'/)
			{
			# if it doesnt, does it contain traditional label quoting
			$trees_single_quoted++;
			};


		# treehub frequently uses the following format, which to me looks like a misinterpretation of the single quoted terminal ids
		# which are used in some older treebuilding software notably where unnaceptable characters are present
		# ./TreeHub_json-zip_20250331/tree/out/T00067857.nwk
		# '\'Salmonella_enterica_subsp._enterica_serovar_Javiana_str._ATCC_BAA-1593\'':0
		# Characters traditionally triggering node label quoting include whitespace, comma and parenthesis. 
		# Due to these chars being central to newick structure definition, they can cause havok and should be avoided,
		# inevitabely some phylogeny users dont care about such things, and use them anyway.
		# The problems caused by such chars include the current task of quantifying terminal id contents,
		# Thus first task is to scan for these, and remove the problematic chars.
		# Contents being searched for are any character that is not a backslash (denoting end of this convention)
		# as we have to assume absolutly anything could be present
		# personally i opt to remove hyphens as they are used in scientifc notation branch lengths, 
		# though this is not a priority,
		# and hyphens are a common component of codes (e.g. specimens), so others would probably be ok with keeping them.
		# NB, developing the regexs was a sequential task of trying to define more and more of the database, 
		# a result being it is unlikely all the regexs are matched in the finalized version
		# due to some later written ones encompassing earlier ones.
		# Names will be checked against taxonomy later, 
		# here we are just extracting component most likely be be a name, 
		# and removing characters making if difficult to read IDs.


		###################################################################################################################
		# UNKNOWN (reason for quoting)

		# T00075128.nwk:'\'s_Cat\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\\\'\'/$1/){$type1++};


		###################################################################################################################
		# (quoting due to) DOUBLE QUOTES
		# /T00000182.nwk treehub_terminalID:'\'Scilla_sp.""monanthos""aff\''
		while($contents =~ s/\'\\\'([A-Za-z\._]+)\"{2,3}([A-Za-z]{3,30})\"{2,3}(\w*)\\\'\'/$1$2$3/){$type2++};

		# T00053691.nwk:'\'""Porotergus""_gimbeli\''
		while($contents =~ s/\'\\\'\"{2,3}([A-Za-z_\.]{3,30})\"{2,3}([A-Za-z_]+)\\\'\'/$1$2/){$type2++};

		# T00067842.nwk:'\'""Septoria""_gladioli_CBS_121.20\''
		while($contents =~ s/\'\\\'\"{2,3}([A-Z][a-z_]{3,30})\"{2,3}([A-Za-z0-9\.\-\/_]+)\\\'\'/$1$2/){$type2++};

		# this is a single node label, not a bunch of stuff combined:
		# T00080925.nwk:'\'Chloromonas_krienitzii,_""Chloromonas_brevispina""_aplanozygotes_Gassan-A/Hakkoda-2\''
		while($contents =~ s/\'\\\'([A-Za-z\._]+)\,_\"{2,3}([A-Za-z_]{3,30})\"{2,3}[_a-zA-Z0-9\-\/]+\\\'\'/$1$2/){$type2++};

		# T00080925.nwk:'\'Chloromonas_sp._NIES-2379/NIES-2380,_""Chloromonas_nivalis""_aplanozygotes_Gassan-C\''
		while($contents =~ s/\'\\\'([A-Za-z\._]+)\-\d+\/[A-Z0-9\-]+\,_\"{2,3}([A-Za-z_]{3,30})\"{2,3}[_a-zA-Z0-9\-]+\\\'\'/$1$2/){$type2++};

		# T00080925.nwk:'\'""Chloromonas_cf._alpina""_CCCryo_032-99\''
		while($contents =~ s/\'\\\'\"{2,3}([A-Za-z_\.]{3,30})\"{2,3}([A-Za-z0-9_]+)\-[0-9A-Z]+\\\'\'/$1$2/){$type2++};


		###################################################################################################################
		# HYPHEN
		# T00000225.nwk:'\'Tenuiculus-Favoliporus\'			
		while($contents =~ s/\'\\\'([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2/e){$type3++};

		# T00046242.nwk:'\'Lactarius_longisporus_AV99-197_Zimb._BB00-1519_Mad.\''
		while($contents =~ s/\'\\\'([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2."_".$3/e){$type3++};

		# multiple hyphens
		# T00000487.nwk: '\'Ceratobasidium_sp._AGDI_ST-SDS-1_AB196643\''
		while($contents =~ s/\'\\\'([A-Za-z0-9\.\_]+)\-[A-Za-z0-9_]+\-([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2/e){$type3++};
		while($contents =~ s/\'\\\'([A-Za-z0-9\.\_]+)\-[A-Za-z0-9_]+\-([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2."_".$3/e){$type3++};
		# T00050224.nwk:'\'Unnamed_Harpellales_18S_CA-9-W10_and_28S_CA-19-W18\''
		while($contents =~ s/\'\\\'([A-Za-z0-9\.\_]+)\-[A-Za-z0-9_]+\-([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\-([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2."_".$3."_".$4/e){$type3++};

		# T00057622.nwk:'\'Schizosaccharomyces_pombe_972h-\''
		while($contents =~ s/\'\\\'([A-Z][a-z][A-Za-z0-9\_\.]+)\-\\\'\'/$1/){$type3++};

		# T00060931.nwk:'\'Cortinarius_uraceus_MM94--0066\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z0-9\.\_]+)\-+([A-Za-z0-9]+)\\\'\'/$1."_".$2/e){$type3++};


		###################################################################################################################
		# PLUS; i think produced by some software where long labels are truncated
		# T00000284.nwk:'\'Outgroup_to_Ranunculus+\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\+[A-Za-z0-9_]{0,20}\\\'\'/$1/){$type4++};

		# T00057622.nwk:'\'Orphella_catalaunica_NOR-40-W10_+_W12\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.\-]+)\+[A-Za-z0-9_]{0,20}\\\'\'/$1/){$type4++};


		###################################################################################################################
		# FORWARD SLASH

		# T00096235.nwk:'\'53/22\''
		while($contents =~ s/\'\\\'([0-9\.\_]+)\/([0-9\_]{0,5})\\\'\'/$1."_".$2/e){$type5++};
		while($contents =~ s/\'\\\'([A-Za-z0-9\-\_]+)\/([A-Z0-9]{0,5})\/([A-Z0-9]{0,5})\\\'\'/$1."_".$2/e){$type5++};

		# T00000366.nwk:'\'Pelorius/Schwartzius\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_]+)\/([0-9A-Za-z_\.]+)\-*[_A-Za-z]*\\\'\'/$1."_".$2/e){$type5++};

		# multiple forward slash
		# T00000555.nwk:'\'Protorhabditis/Prodontorhabditis/Diploscapter\''
		while($contents =~ s/\'\\\'([A-Z][a-z]+)\/([A-Z][a-z]+)\/([A-Z][A-Za-z_]+)\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00004433.nwk:'\'South_East_Asia/Australia/Zanzibar/Hawaii\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_]+)\/([A-Z][a-z_]+)\/([A-Z][a-z_]+)\/([A-Z][a-z_]+)\\\'\'/$1."_".$2."_".$3."_".$4/e){$type5++};

		# T00005435.nwk:'\'Pteridium_aquilinum_ssp._centrali-africanum_112_CH3Z/ZAMB\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_\.]+)\-([A-Za-z0-9_]+)\/([A-Z][A-Za-z_]+)\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00025834.nwk:'\'CR07/2-4\''
		while($contents =~ s/\'\\\'([A-Z0-9]+)\/\d+\-\d+\\\'\'/$1/e){$type5++};

		# T00050574.nwk:'\'Stigmatella_aurantiaca_DW4/3-1\''
		while($contents =~ s/\'\\\'([A-Za-z_]+_[A-Z0-9]+)\/\d+\-\d+\\\'\'/$1/e){$type5++};

		# T00026546.nwk:'\'Cortinarius_luteo-ornatus_MM1962/0027_Type\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+)\-([a-z]+_[A-Z0-9]+)\/([A-Za-z0-9_]+)\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00031295.nwk:'\'Rhizoctonia_sp._85-387/Na_AF200519\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z0-9_\.]+)\-([A-Za-z0-9]+)\/([A-Za-z0-9_]+)\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00050575.nwk:'\'Natranaerobius_thermophilus_JW/NM-WN-LF\''
		while($contents =~ s/\'\\\'([A-Za-z_]+_[A-Z0-9]+)\/[A-Z\-]{5,10}\\\'\'/$1/e){$type5++};

		# T00052017.nwk:'\'Aspergillus_terreus_UOA/HCPF_ENV32-1.2\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\/[A-Z0-9\-\.\_]{5,15}\\\'\'/$1/){$type5++};

		# difficult to notice in the context of the TreeHub quoteing convention: there is a forward slash before name
		# T00000611.nwk: ):0.00000)'\'/Hebeloma\'':0.00000,
		while($contents =~ s/\'\\\'\/([A-Za-z]+)\\\'\'/$1/){$type5++};

		# T00062028.nwk:'\'Fiona_pinnata_Morocco_MNCN/ADN:_51997\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z\_\.]+)\/[A-Z]+\:[0-9_]+\\\'\'/$1/){$type5++};

		# T00003119.nwk:'\'Togninia_griseo-olivacea_EU128097/EU128139\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+)\-([a-z]+)_([A-Z0-9]+)\/[A-Z0-9]+\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00063712.nwk:'\'Lactifluus_longisporus_AV99-197/BB_00.1519\''
		while($contents =~ s/\'\\\'([A-Z][a-z][A-Za-z0-9_\.]+)\-\d+\/([A-Z0-9\.\_]+)\\\'\'/$1."_".$2/e){$type5++};
		while($contents =~ s/\'\\\'([A-Z][a-z][A-Za-z0-9_\.]+)\/[A-Z0-9\.\_\-]+\\\'\'/$1/){$type5++};

		# T00070451.nwk:'\'Chloromonas_cf._schussnigii_CCCryo_082-99/Chloromonas_cf._insignis_CCCryo_090-99\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z0-9_\.]+)\-([A-Z0-9]+)\/([A-Za-z0-9_\.]+)\-[a-z0-9]+\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00072536.nwk:'\'Hyaloperonospora_thlaspeos-perfoliati_D24/4/99\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_]+)\-([a-z]+)_([A-Z0-9]+)\/[0-9\/]{1,9}\\\'\'/$1."_".$2."_".$3/e){$type5++};

		# T00076758.nwk:'\'Branchiostoma_floridae_Gdf8/Tgfb-like\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\/[A-Za-z0-9\-\.\_]{5,15}\\\'\'/$1/){$type5++};

		# T00079987.nwk:'\'Chloromonas_sp._NIES-2379/Gassan-C\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\-\d+\/[A-Za-z0-9\-\.\_]{5,15}\\\'\'/$1/){$type5++};


		# T00077477.nwk:'\'Chlamydia_trachomatis_D/UW-3/CX_NC_000117\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\/[A-Za-z0-9\-\.\_]{1,15}\/[A-Za-z0-9\.\_]{5,25}\\\'\'/$1/){$type5++};


		###################################################################################################################
		# STAR; looks like the kind of study specific thing, which should be removed before data provision
		# T00000717.nwk:'\'*\''
		while($contents =~ s/\'\\\'(\*)\\\'\'//){$type6++};
		while($contents =~ s/\'\\\'([A-Z][A-Za-z0-9\.\_]{5,25})\*\\\'\'/$1/){$type6++};

		# T00027455.nwk:'\'Cylindrocarpon_sp.*_\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\.*\*_*\\\'\'/$1/){$type6++};

		# T00062035.nwk:'\'Geomys_pinetis_mobilensis_12327_Decatur_GA*_1940\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\*[0-9\_]+\\\'\'/$1/){$type6++};

		# T00076538.nwk:'\'Grapevine_leafroll-associated_virus_3_KF417601-Traminette-USA_*\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-[A-Za-z0-9\_\-]+\*\\\'\'/$1/){$type6++};



		###################################################################################################################
		# EQUALS;
		# T00000932.nwk:'\'Paniceae_x_=_9\''
		# T00006418.nwk:'\'The_two_species_of_Biatora_studied_in_the_paper._MPBS=_78\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\=[0-9_]+\\\'\'/$1/){$type7++};

		# T00006418.nwk:'\'Pilocarpaceae_-_MPBS=99\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\-[_A-Z]+\=[0-9_]+\\\'\'/$1/){$type7++};

		# T00062529.nwk:'\'Phytophthora_sp._PgChlamydo_CMW35277=PF23\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\=[A-Za-z0-9_\.]+\\\'\'/$1/){$type7++};

		# T00077477.nwk:'\'Streptomyces_avermitilis_MA-4680_=_NBRC_14893_NC_003155\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)[\-][_0-9]+\=[A-Za-z0-9_\.]+\\\'\'/$1/){$type7++};
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\=[A-Z0-9_]+\-[A-Za-z0-9_\.]+\\\'\'/$1/){$type7++};



		###################################################################################################################
		# QUESTION MARKS, an ineviatable character and not a big issue, remove anyway
		# T00001116.nwk:'\'Drechslera_sp._-?_cbs201.29\''
		# T00048692.nwk:'\'Stegodyphus_sarasinosum_15-10?\''
		while($contents =~ s/\'\\\'([A-Z][a-z_\.]+)[\-\?0-9]+([a-z0-9\.\_]*)\\\'\'/$1."_".$2/e){$type8++};



		###################################################################################################################
		# CURLEY BRACE; pair
		# T00001309.nwk:'\'Pterocephalus_{asi}\''
		# T00001591.nwk:'\'Bartsia_{inc_Bellardia}\''
		# T00001607.nwk: '\'Alnus_{2}\''
		# T00004243.nwk:'\'Secale_strict.cerea_{3.8}\''
		while($contents =~ s/\'\\\'([A-Z][a-z_\.]+)\{([0-9A-Za-z_\.]+)\}\\\'\'/$1."_".$2/e){$type9++};

		# T00003803.nwk:'\'Procavicola_{Procavicola}_eichleri\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+)\{([0-9A-Za-z_]+)\}([a-z_\-\.]+)\\\'\'/$1."_".$2."_".$3/e){$type9++};



		###################################################################################################################
		# CURLEY BRACE; closing; meaningless node label
		# T00001343.nwk: (Outgroup_to_Onagraceae:0.00000)'\'}\'':0.00000):0.00000;
		while($contents =~ s/\'\\\'(\})\\\'\'//){$type10++};

		# T00002508.nwk:'\'Cylindrocarpon_destructans_-4/97-1\''
		while($contents =~ s/\'\\\'([A-Z][a-z_\.]+)_[\-\/0-9]{3,9}\\\'\'/$1/){$type10++};

		# T00002522.nwk:'\'Tiquilia_palmeri--Salton_Sea\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+)[\-]+([0-9A-Za-z_]+)\\\'\'/$1."_".$2/e){$type10++};



		###################################################################################################################
		# PARENTHESES: finally we get to one of the real problematic characters, since they define the newick structure
		# will keep the regexes strict as possible in these cases
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20}_)\(([A-Z][a-z]{2,20})\)(_[a-z]{3,20})\\\'\'/$1."_".$2."_".$3/e){$parenth++};

		# T00025652.nwk:'\'Stephanodiscus_subtransilvanicus_(African_Fossil)\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20}_[a-z]{2,20})_\(([A-Z][a-z]{2,20}_[A-Z][a-z]{2,20}[_A-Za-z]*)\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00027640.nwk:'\'HQ117861_Endophyte_(Casearia_prunifolia_Ecuador)\''
		while($contents =~ s/\'\\\'([A-Z0-9]+_[A-Z][a-z_]{2,30})_\(([A-Z][a-z]{2,20}_[A-Za-z]{2,20}[_A-Za-z]*)\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00027640.nwk:'\'FJ025239_Endophyte_(broad-leaved_plant_China)\''
		while($contents =~ s/\'\\\'([A-Z0-9]+_[A-Z][a-z]{2,20})_\(([a-z]{2,20})\-([A-Za-z_]{2,40})\)\\\'\'/$1."_".$2."_".$3/e){$parenth++};

		# T00050742.nwk:'\'AM049960_Halimeda_macroloba_(Tanz)\''
		while($contents =~ s/\'\\\'([A-Z0-9]+_[A-Z][a-z]{2,20}_[a-z]+)_\(([A-Za-z]{2,20})\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00052565.nwk:'\'Teratosphaeria_nubilosa_CMW_30735_Tasmania(Group_B)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\(([A-Za-z_]{2,20})\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00052565.nwk:'\'Teratosphaeria_nubilosa_CMW_3282_ex-epitype_Victoria(Group_C)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-[A-Za-z_]+\(([A-Za-z_]{2,20})\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00049838.nwk:'\'Megadytes_(Megadytes)_sp\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20})_\(([A-Z][a-z]{2,20})\)_([A-Za-z_]{2,40})\\\'\'/$1."_".$2."_".$3/e){$parenth++};

		# T00058304.nwk:'\'Lasioglossum_(Parasphecodes)_hybodinum_AF104660\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20})_\(([A-Z][a-z]{2,20})\)_([A-Za-z_0-9]{2,40})\\\'\'/$1."_".$2."_".$3/e){$parenth++};

		# T00031295.nwk:'\'Ceratobasidium_sp._AG-B(o)_DQ279057\''
		# another reminder, we need to remove parentheses (and certain other chars) from users node identifiers, 
		# otherwise newick structure parsing including reading terminal IDs (which uses parentheses) is more complex and error prone
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\-\w+\([a-z]{1,20}\)([A-Za-z0-9_]{2,40})\\\'\'/$1."_".$2/e){$parenth++};

		# T00031295.nwk:'\'vouchered_mycorrhizae_(Basidiomycota)_AB303044\''
		while($contents =~ s/\'\\\'([a-z_]{2,40}_)\(([A-Z][a-z]{2,20})\)(_[A-Z0-9]{2,40})\\\'\'/$1."_".$2."_".$3/e){$parenth++};

		# T00025870.nwk:'\'Bracteacoccus_cohaerens_(UTEX_1272)\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20}_[a-z]{2,20})_\(([A-Z]+_[0-9]+)\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00050742.nwk:'\'IRD_5300_morphotype_D_(NC)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]{10,30}_)\(([A-Z0-9]+)\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00025870.nwk:'\'Bracteacoccus_cohaerens_(SAGS05-1)\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20}_[a-z]{2,20})_\([A-Z0-9\-_]+\)\\\'\'/$1/e){$parenth++};

		# T00025872.nwk:'\'Scenedesmus_deserticola_(YPGChar)\''
		while($contents =~ s/\'\\\'([A-Z][a-z]{2,20}_[a-z]{2,20})_\([A-Za-z0-9]+\)\\\'\'/$1/e){$parenth++};

		# T00050742.nwk:'\'IRD_5326_morphotype_A_-_Halimeda_cylindracea_(NC)\''
		# T00050746.nwk:'\'IRD_5810_morphotype_T_-_Halimeda_melanesica_(NC)*\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-(_[A-Z][a-z]{2,20}_[a-z]{2,20})_\([A-Za-z0-9]+\)\**\\\'\'/$1."_".$2/e){$parenth++};
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-(_[A-Z][a-z]{2,20}_[a-z]{2,20})_\([A-Za-z0-9\-]+\)_+\\\'\'/$1."_".$2/e){$parenth++};

		# T00050749.nwk:'\'HV1828_XX_Halimeda_fragilis2_(Mal)\'' '\'IRD_5319_morphotype_D_(Chest-NC)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)_\([A-Za-z0-9\-\._]+\)[\*\_]*\\\'\'/$1/){$parenth++};

		# T00050749.nwk:'\'IRD_5318_morphotype_D_-_Halimeda_fragilis_(Chest-NC)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-(_+[A-Z][a-z_]{2,30})_\([A-Za-z0-9\-]+\)\**\\\'\'/$1."_".$2/e){$parenth++};

		# T00050746.nwk:'\'CP08_908_Halimeda_borneensis_(FP)__\'' .......... '\'AM049959_Halimeda_kanaloana_(H)_*\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]{10,30}_)\(([A-Za-z0-9]+)\)_+\**\\\'\'/$1."_".$2/e){$parenth++};

		# T00051245.nwk:'\'Rhytismataceae_sp._T4N25a(B)_AY465499\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\([A-Za-z0-9]+\)(_[A-Z0-9]+)\\\'\'/$1."_".$2/e){$parenth++};

		# T00055280.nwk:'\'Thiratoscirtus_sp._(small_bulb)_2\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([A-Za-z_]+\)_[A-Z0-9]+\\\'\'/$1/){$parenth++};

		# T00062031.nwk:'\'Dicata_odhneri_Spain_(ATL)_MNCN_15.05/53692\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([A-Za-z_]+\)_[A-Z0-9\_\.]+\/\d+\\\'\'/$1/){$parenth++};

		# T00062284.nwk:'\'Acacia_saligna_(Labill.)_H.L.Wendl.\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([A-Za-z0-9_\.]+\)_[A-Za-z\_\.]+\\\'\'/$1/){$parenth++};
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([A-Za-z_\.]+\)_[A-Za-z\_\.]+[\&][A-Za-z_]+\\\'\'/$1/){$parenth++};

		# T00062284.nwk:'\'Acacia_tropica_(Maiden_&_Blakely)_Tindale\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([A-Za-z0-9_\&]+\)[A-Za-z\_\.]*\\\'\'/$1/){$parenth++};

		# T00075215.nwk:'\'Salinivibrio_siamensis_ND1-1T_(AB285018)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_]+)\-([A-Z0-9]{2,20})_\([A-Za-z0-9\-]+\)\\\'\'/$1."_".$2/e){$parenth++};

		# T00075593.nwk:'\'Geastrum_britannicum_K(M)_79617_Holotype\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.\_]+)\([A-Za-z_]+\)(_[A-Za-z0-9\_\.]+)\\\'\'/$1."_".$2/e){$parenth++};

		# T00077477.nwk:'\'Synechococcus_sp._JA-2-3Ba(2-13)_NC_007776\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\-[0-9A-Za-z\-]+\([A-Za-z0-9\-]+\)_[A-Z0-9_]+\\\'\'/$1."_".$2/e){$parenth++};

		# T00079949.nwk:'\'XP_004250372(S.lycopersicum)\''
		# T00079953.nwk:'\'AAG49002(H.vulgare)____\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\([A-Za-z_\.]+\)_{0,10}\\\'\'/$1/){$parenth++};
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\([A-Za-z_\.\-]+\)_[A-Z0-9]+\\\'\'/$1/){$parenth++};

		# T00087991.nwk:'\'Elaphoglossum_decoratum_(NYBG391/77B)\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.\_]+)\([A-Z0-9]+\/[A-Z0-9]+\)\\\'\'/$1."_".$2/e){$parenth++};



		###################################################################################################################
		# HASH, unadvisable due to being used to denote text to be ignored, in many environments
		# T00003559.nwk:'\'Ustilago_hordei_316_#14.1_MAT-2\''
		while($contents =~ s/\'\\\'([A-Z][a-z0-9_]+)[\#]([0-9A-Z_\.\-]+)\\\'\'/$1."_".$2/e){$type11++};



		###################################################################################################################
		# COMMA: the second major problematic character in users node label, would easily be mistaken for a node delimitor.
		# again need to have very precise removal, as to avoid removing node delimitors
		# T00050224.nwk:'\'Austrosmittium_biforme_32-1-9,_32-1-8\''
		while($contents =~ s/\'\\\'([A-Z][a-z]+_[a-z]+_[0-9]+)[0-9\-]{1,5}\,_[0-9\-]{5,9}\\\'\'/$1/){$commas++};
	
		# never seen this before, a comb denoted as a node label. 
		# again 1) this should not have commas in the first place, 2) treehub should have repared in the second place.
		# T00050266.nwk:('\'Ficus_erecta_ZHS023,_Ficus_boninsimae,_Ficus_nishimurae,_Ficus_iidaiana\'':0.00000,Ficus_erecta
		while($contents =~ s/\'\\\'([A-Z][a-z_]+_[A-Z0-9]+)\,([A-Za-z_]+)\,([A-Za-z_]+)\,([A-Za-z_]+)\\\'\'/$1."_".$2."_".$3."_".$4/e){$commas++};
		while($contents =~ s/\'\\\'([A-Za-z_]+)\,([A-Za-z_]+)\\\'\'/$1."_".$2/e){$commas++};

		# T00053872.nwk:'\'see_F,G,H\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\,([A-Z]+)\,([A-Z]+)\\\'\'/$1."_".$2."_".$3/e){$commas++};
		while($contents =~ s/\'\\\'([A-Za-z_]+)\,([A-Z]+)\,([A-Z]+)\,([A-Z]+)\\\'\'/$1."_".$2."_".$3."_".$4/e){$commas++};

		# T00055085.nwk:'\'Chloromonas_chlorococcoides_SAG_12.96,_SAG_15.82,_SAG_16.82\''
		while($contents =~ s/\'\\\'([A-Za-z0-9\._]+)\,([A-Z0-9\.\_]+)\,([A-Z0-9\.\_]+)\\\'\'/$1."_".$2."_".$3/e){$commas++};

		# T00060049.nwk:'\'citrus_exocortis_viroid_tomato_hybrid_callus,_CEVcls_370_\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\,([A-Za-z0-9_]+)\\\'\'/$1."_".$2/e){$commas++};

		# T00060049.nwk:'\'Citrus_exocortis_viroid,_host=Vicia_faba\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+)\,[A-Za-z_\=]+\\\'\'/$1/){$commas++};

		# T00060095.nwk:'\'Sericipterus_wucaiwanensis,_gen._et_sp._nov.\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_]+)\,([A-Za-z0-9_\.]+)\\\'\'/$1."_".$2/e){$commas++};
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\,([A-Za-z0-9_]+)\\\'\'/$1."_".$2/e){$commas++};

		# T00067857.nwk:'\'Salmonella_enterica_subsp._houtenae_serovar_50:g,z51:-_str._01-0133\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]+)\:[a-zA-Z]+\,[a-z0-9]+\:[\-_\.0-9a-z]+\\\'\'/$1/){$commas++};

		# T00067857.nwk:'\'Salmonella_enterica_subsp._diarizonae_serovar_60:r:e,n,x,z15_str._01-0170\''
		while($contents =~ s/\'\\\'([A-Z][a-z][a-z0-9_\.]+)\:[a-z]\:[a-z]\,[a-z\,]{1,10}[\-_\.0-9a-z]+\\\'\'/$1/){$commas++};

		# T00067857.nwk:'\'Salmonella_enterica_subsp._salamae_serovar_58:l,z13,z28:z6_str._00-0163\''
		while($contents =~ s/\'\\\'([A-Z][a-z][a-z0-9_\.]+)\:[a-z]\,[a-z0-9]+\,[a-z0-9\:]{1,10}[\-_\.0-9a-z]+\\\'\'/$1/){$commas++};

		# T00067857.nwk:'\'Salmonella_enterica_subsp._indica_serovar_6,14,25:z10:1,(2),7_str._1121\''
		while($contents =~ s/\'\\\'([A-Z][a-z][a-z0-9_\.]+)\,[a-z0-9]+\,[a-z0-9\:\,]{1,10}\(\d\)[\,\._0-9a-z]+\\\'\'/$1/){$commas++};

		# T00070451.nwk:'\'Chloromonas_sp._red_flagellates,_sample_HW01/clone1\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\,([A-Za-z0-9_]+)\/[A-Za-z0-9]+\\\'\'/$1."_".$2/e){$commas++};

		# T00077477.nwk:'\'Salmonella_enterica_subsp._arizonae_serovar_62:z4,z23:-_str._RSK2980_NC_010067\''
		while($contents =~ s/\'\\\'([A-Z][a-z][A-Za-z0-9\.\_]+)[\:a-z0-9]+\,[A-Za-z0-9\:\-\._]+[A-Z0-9_]+\\\'\'/$1/){$commas++};

		# T00079987.nwk:'\'Gassan-B,_Hakkoda-3\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\-[A-Z0-9]+\,([A-Za-z0-9_]+)\-[A-Z0-9]+\\\'\'/$1."_".$2/e){$commas++};
		while($contents =~ s/\'\\\'([A-Za-z_]+)\/[A-Za-z0-9\-]+\,([A-Za-z0-9_]+)\-[A-Z0-9]+\\\'\'/$1."_".$2/e){$commas++};

		# T00081028.nwk:'\'Mycobacterium_marinum_M,_ATCC_BAA-535\''
		while($contents =~ s/\'\\\'([A-Z][A-Za-z_]+)\,[A-Za-z0-9_\-\.]+\\\'\'/$1/){$commas++};


		###################################################################################################################
		# worst offenders thus far, something formatted exactly as a split, within a node/branch id not corrected denoted as such
		# T00055280.nwk:'\'thiratoscirtine_(small_cross,_litter)\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\([a-z_]+\,[a-z_]+\)\\\'\'/$1/){$type12++};

		# T00055280.nwk:'\'Pochyta_sp._(orange,_black_spot)\''
		while($contents =~ s/\'\\\'([A-Za-z_\.]+)\([a-z_]+\,[a-z_]+\)\\\'\'/$1/){$type12++};

		# T00055280.nwk:'\'thiratoscirtine_(large,_freyine-like)\''
		while($contents =~ s/\'\\\'([A-Za-z_]+)\([a-z_]+\,[a-z_\-]+\)\\\'\'/$1/){$type12++};


		###################################################################################################################
		# AMPERSAND, inevitable in terminal ids from some users as a shorthand way of giving alternatives.
		# In treehub (and thus presumably treebase) the ampersand appears in itself not a quaotable char, see e.g.:
		# ./TreeHub_json-zip_20250331/tree/out/T00062284.nwk
		# Char is used in some older software before denotation of tree type (Rooted or Unrooted),
		# though unlikely to be mistakenly parsed as such. Not a priority issue.
		# T00050224.nwk:'\'Stachylina_grandispora_KS-70-W11&18\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+[A-Z]+)\-\d+\-([A-Z0-9]+)\&\d+\\\'\'/$1."_".$2/e){$type13++};


		###################################################################################################################
		# SQUARE BRACKETS
		# use to define character sets in pattern matchine, as herein
		# some software uses to denote node labels, here is different as is within the label.
		# T00075582.nwk:'\'Cystopteris_bulbifera_6116_On_c12_[2_4_5_9_14_10_11_15_1_3_8_7]\''
		while($contents =~ s/\'\\\'([A-Z][a-z_]+[0-9A-Za-z_]+)\[[0-9_]+\]\\\'\'/$1/){$type14++};

		# T00112918.nwk:'\'[Eubacterium]_cellulosolvens_I5AQS9_EUBCE\''
		while($contents =~ s/\'\\\'\[([A-Za-z0-9_]+)\]([A-Za-z0-9_]+)\\\'\'/$1$2/){$type14++};


		###################################################################################################################
		# COLON
		# used to denote branch lengths in both terminals and internal nodes
		# T00077477.nwk:'\'Escherichia_coli_O157:H7_str._EDL933_NC_002655\''
		while($contents =~ s/\'\\\'([A-Z][a-z][A-Za-z0-9_]+)\:([A-Za-z0-9\.\_]+)\\\'\'/$1."_".$2/e){$type15++};



		###################################################################################################################
		# GENERAL
		# reasonable effort has now been made to precision parse, accounts for most of the database,
		# will now use more general purpose to get outliers
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]{3,40})[A-Za-z0-9\.\_\-\:\,\/\(\)\{\}\[\]\*\?\&\+\=]{5,100}\\\'\'/$1/){$outliers++};

		# bit wary of the vertical pipe, it can break regexs
		# T00098661.nwk:'\'Fusarium_solani_FRC.2432_*_FSSC_39-a|\''
		while($contents =~ s/\'\\\'([A-Za-z0-9_\.]{2,40})[A-Za-z0-9\.\_\-\:\,\/\(\)\{\}\[\]\*\?\&\+\=]{5,100}\|\\\'\'/$1/){$outliers++};



		##########################################################################################################################
		##########################################################################################################################
		##########################################################################################################################

		# TreeHub has also the traditional single quotes,
		# including problematic cases, particularly IDs containing the bifurcation-like char structure:
		# T00170796.nwk; ('JX828137 Neosiphonia yendoi (Gangwondo, South Korea)':0.0344,'AF342903 Polysiphonia japonica (Honshu, Japan)':
		# Hopefully there arent too many of these, 
		# in some ways they are more problematic that the (seemingly accidental) treehub quoting convention,
		# because there is no difference between the start and stop delimitor (both just ').
		# Simplest immediate solution will be to reference these against the start of the file.
		# This regex will just count this class and delete.
		# Needs to not match the treehub quoted labels, thus dont match backslashes.
	#	my $single_quoted=0; # print "\n$contents\n";
		while($contents =~ s/^([^\'\\]+)\'([^\'\\]+)\'/$1$2/)
			{
			my $matchedID = $2;$single_quoted++; # print "matchedID:$matchedID\n"
			};
		# if($single_quoted >= 1){die ""}



	# 	for testing
	#	if($contents =~ /(\'\\\'[^\\]+\\\'\')/)
	#		{
	#		my $treehub_terminalID = $1; print "file:$file treehub_terminalID:$treehub_terminalID\n";
	#		unless($file =~ /T0006785|T0008092|T0009607|T00100542|T0011445/){	
	#		die "";
	#		};
	#		};







		##########################################################################################################################
		##########################################################################################################################
		##########################################################################################################################


		# CODED TREES


		# Above makes sure terminals can be parsed more precisly
		# First find simpler formatted, fully coded trees, such as those produced by simulations, 
		# that dont need to go through the more complex parsing
		# a general note on parsing terminal ids, 
		# the patterns must not start with a close bracket otherwise internal node labels will be picked up
		# one characteristic of codes is they will almost alweays be shorter than linnean names

		# simplest format, numbered terminal IDs
		my $codes_class1=0;
		while($contents =~ s/([\(\,])([0-9]{1,8})([\)\(\,\:])/$1$3/)
			{
			$codes_class1++;
			};

		# highly abbreviated tax names
		# already this is akward to differentiate from short genus names,
		# thus need to check each name againt the tax database
		# my $codes_class2=0;
		while($contents =~ s/([\(\,])([A-Z][a-z]{1,4})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		my $codes_class3=0;
		# well formatted codes, uppercase letters followed by numbers
		# T00000821: ,Leotia:0.00000):0.00000,(((((CR483:0.00000,CR478:0.00000):0.0
		while($contents =~ s/([\(\,])([A-Z]{1,3}[0-9]{0,8})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};
		
		my $codes_class4=0;
		# acceptable code format, easy to differentiate
		# T00047735.nwk: (Outgroup:0.27291,(((((((Ha66:0.00120,Ha64:0.00120)0.78
		while($contents =~ s/([\(\,])([A-Z][a-z][0-9]{0,8})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		my $codes_class5=0;
		# T00053045.nwk: ,Cornipulvina_ellipsoides:0.03609):0.03548,(((150L:0.14698,((158L:0.00943,
		# numbers/letters opposite order than conventional, otherwise easy to parse
		while($contents =~ s/([\(\,])([0-9]{1,5}[A-Z]{1,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00053580.nwk: (OtV1:0.01579,OtV06_1:0.02378):0.01553,OtV5:0.01556)
		# parsable
		my $codes_class6=0;
		while($contents =~ s/([\(\,])([A-Z][a-z][A-Z][0-9]{1,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00003693.nwk: P3_2
		my $codes_class7=0;
		while($contents =~ s/([\(\,])([A-Z][0-9]{1,3}_[0-9]{1,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00070375.nwk:sn8a
		my $codes_class8=0;
		while($contents =~ s/([\(\,])([a-z]{1,3}[0-9]{1,3}[a-z]{0,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00061109.nwk:IBDV
		my $codes_class9=0;
		while($contents =~ s/([\(\,])([A-Z]{2,4})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00075655.nwk:GbNV
		my $codes_class10=0;
		while($contents =~ s/([\(\,])([A-Z][a-z]{1,3}[A-Z]{1,4})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00079721.nwk:BP7B
		my $codes_class11=0;
		while($contents =~ s/([\(\,])([A-Z]{1,3}[0-9]{1,4}[A-Z]{1,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00118358.nwk:N_43
		my $codes_class12=0;
		while($contents =~ s/([\(\,])([A-Z][0-9]{0,4}_*[0-9]{0,3})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# yes, this tree has terminal ids of a single lowercase letter
		# T00123541.nwk:b
		my $codes_class13=0;
		while($contents =~ s/([\(\,])([a-z])([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00124639.nwk:A4s6
		my $codes_class14=0;
		while($contents =~ s/([\(\,])([A-Z][0-9]+[a-z][0-9]+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# terminal ids formatted as floating point, exactly like branch lengths thus poor choice
		# T00124658.nwk: 27.3
		my $codes_class15=0;
		while($contents =~ s/([\(\,])([0-9]+\.[0-9])([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00140032.nwk:_t5_
		my $codes_class16=0;
		while($contents =~ s/([\(\,])(_+[a-z][0-9]+_+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# this terminal code class, more likely to be part of a tree that elsewhere contains tax names
		# T00141432.nwk:sp_5
		my $codes_class17=0;
		while($contents =~ s/([\(\,])(sp_[0-9]+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# sloppy formatting; despite using only 3 alphanumerical chars, manages to be inconsistent
		# T00155067.nwk; sID:53_1, 5M_A 
		my $codes_class18=0;
		while($contents =~ s/([\(\,])([0-9][0-9A-Z]_[0-9A-Z])([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00155818.nwk: #H1
		my $codes_class19=0;
		while($contents =~ s/([\(\,])(\#[A-Z]{0,2}[0-9]{1,4})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00158467.nwk:lacl
		my $codes_class20=0;
		while($contents =~ s/([\(\,])([a-z]{2,4})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00168544.nwk:CDio
		my $codes_class21=0;
		while($contents =~ s/([\(\,])([A-Z]{2,4}[a-z]{1,2})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00170691.nwk:CcXh
		my $codes_class22=0;
		while($contents =~ s/([\(\,])([A-Z]{1,4}[a-z0-9][A-Z0-9][a-z])([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};
		my $codes_class23=0;
		while($contents =~ s/([\(\,])([A-Z][0-9]+[a-z])([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00171907.nwk:Tax4
		my $codes_class24=0;
		while($contents =~ s/([\(\,])(Tax[0-9]+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00183589.nwk:Chl0
		my $codes_class25=0;
		while($contents =~ s/([\(\,])(Chl[0-9]+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00184334.nwk:FO_4
		my $codes_class26=0;
		while($contents =~ s/([\(\,])([A-Z][A-Za-z0-9]_[0-9]*)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		# T00184783.nwk:Pig4
		# not exactly a code, but practically unusable anyway
		my $codes_class27=0;
		while($contents =~ s/([\(\,])([A-Z][a-z]{1,2}[0-9]+)([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};
		while($contents =~ s/([\(\,])([0-9]+[A-Z][a-z]{1,2})([\)\(\,\:])/$1$3/)
			{
			my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
		#	print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
			$codes_class1++;
			};

		if($codes_class1 >= 3){$trees_with_coded_terminals++};








	#	my $codes_class35=0;
	#	while($contents =~ s/([\(\,])([^\(\)\,\:]{1,4})([\)\(\,\:])/$1$3/)
	#		{
	#		my $terminus_start = $1; my $terminusID = $2;my $terminus_end = $3;
	#		print "file:$file\tterminus_start:$terminus_start terminusID:$terminusID terminus_end:$terminus_end\n";
	#		$codes_class35++;
	#		};
	#	if($codes_class35 >= 4){die ""};
		# due to trees can be partially coded, eg T00000821 above, need to quantify proportions and decide how to class them


		# Earlier, simple way the trees were scanned, no longer used
		# Scan for taxonomic names in terminal IDs, count for current tree.
		# Characters immediately prior to terminal IDs will be either open parenthesis or comma.
		# Taxonomic name must be single upper case A-Z followed by multiple lower case character.
		# Taxonomic name may be prefixed with code or higher taxon (less common),
		# and is usually suffixed with several possible components, 
		# (most commonly lowercase species name, codes, taxonomic shorthand).
		# Terminal ID ends with either close parenthesis, comma, or colon.
		# Disclaimer: wont pick up very wide deviation of terminal IDs to recognized standards.
	#	my %taxa=(); 
	#	while( $contents =~ s/([\(\,])([^\,\)\(\:]*)([A-Z][a-z]{2,}[_a-z]*)([^\,\)\(\:]+)/$1/)
	#		{
	#		my $split_start = $1; my $ID_prefix = $2; my $taxon = $3; $ID_suffix = $4;$taxa{$taxon}=1;
	#		} 
	#	my @list_taxa = keys %taxa;
	#	if (scalar @list_taxa >= 4) 
	#		{
	#		$phylogenies++;
	#		}else{
	#		$treelike++;
	#		};






		##########################################################################################################################
		##########################################################################################################################
		##########################################################################################################################


		# remove characters that definately should not be there. 
		# vertical pipe included, though i like it as a field delimitor, for current purpose it can interfeer with pattern matching
		# slashes acceptable in internal labels, which is outside current topic
		# T00000284.nwk: ,'\'Outgroup_to_Ranunculus+\'':0.00000)
		# T00000290.nwk: ,Botryococcus_braunii_CCAP_807/1:0.00000)
		# T00000543.nwk: ,Pinnocaris?_sp._C:0.00000):0
		# T00000932.nwk: )'\'Paniceae_x_=_9\'':0.0
		# T00001309.nwk: Pterocephalus_{asi}\'':0
		# T00001322.nwk:,Cypella_&_Cipura:0.0000

		$contents =~ s/[\=\*\"\|\+\/\?\{\}\&]+//g;

		# One of the biggest errors in newick use that complicates parsing
		# is incorrect parenthesis use, will try and correct a few of these.
		# due to 2 seperate things, difficult to seperate these so will correct at same time:
		# 1) parentheses in terminal IDs 2) single child nodes
		# key uniting aspect of these incorrect parenthesis uses is there wont be a comma within the pair
		# probably the only justified use is added subgenus names to binomials, in quoted IDs, check for those
		# appears all these cases are treebase data


		if($contents =~ s/\(([A-Za-z_]{10,50})\:[0-9\.]{1,10}\)/$1/g)
			{
			# T00001343.nwk (Outgroup_to_Onagraceae:0.00000)

			}elsif($contents =~ s/([a-z]_)\([A-Z][a-z]+\)_([a-z])/$1$2/g)
			{
			# ,('\'Jesogammarus_(Annanogammarus)_debilis\''

			}elsif($contents =~ s/\(([A-Z][a-z]+_[a-z]+_[A-Z][a-z]+[A-Z0-9]+)\:[0-9\.]+\)[0-9\.]+/$1/g)
			{
			# 08,(Triturus_karelinii_TkarA14:0.00804)1.00:0.03914,(Tri

			}elsif($contents =~ s/(\'[A-Z][a-z]+_[a-z]+)_\([A-Za-z_]+\)/$1/g)
			{
			# /T00025652.nwk ('\'Stephanodiscus_subtransilvanicus_(African_Fossil)\'':0.00000

			}elsif($contents =~ s/(\'[A-Z][a-z]+_[a-z]+_)\(([A-Z]+_*[0-9]+\-[0-9]+)\)/$1$2/g)
			{
			# T00025870.nwk: '\'Bracteacoccus_cohaerens_(SAGS05-1)\'':0.

			}elsif($contents =~ s/(\'[A-Z]+\d+_[A-Z][a-z]+_)\(([A-Za-z_]+)\)/$1$2/g)
			{
			# T00027640.nwk: ,('\'EU009996_Endophyte_(Coffea_arabica_Hawaii)\'':

			}elsif($contents =~ s/(\'[A-Za-z_]+_)\(([A-Za-z_]+)\)/$1$2/g)
			{
			# T00031295.nwk: 'vouchered_mycorrhizae_(Basidiomycota)_AB303051\

			}elsif($contents =~ s/\(([A-Z][a-z]+_sp\._[A-Za-z]+)\:[0-9\.]+\)/$1/g)
			{
			# T00048991.nwk: ((Aspidodera_sp._Temazcal:0.00499):0.00749

			}elsif($contents =~ s/([A-Z][a-z]+_[a-z]+_)\((\d+)\)/$1$2/g)
			{
			# T00049599.nwk: '\'Carex_arenaria_(2)\'':0.00

			}elsif($contents =~ /(\([^\,\(]+\))/)
			{
			my $error=$1;
	#		print "file:$file\ncontents:$contents\nerror:$error\n";die "";
			}elsif($contents =~ /\([^\,]+\)/)
			{
		#	print "contents:$contents\n";die "";
			
			};

		if($fileparse_counter > 22400)
			{
			}


		# T00000182: 0000)Scilla:0.0
		# T00000235.nwk: 0000):0.00000)Peziza_s._str._a__b:0.00000):0.00
		# 000)CentothecaCyperochloa_clade:0.0000
		# i hereby dont consider taxon names on internal node labels:
		while($contents =~ s/(\))[\_A-Za-z0-9\.]+(\:)/$1$2/){};

		# Flavoparmelia_aff._caperata:0.0
		while($contents =~ s/([a-z]_)aff\._([a-z])/$1$2/){};
		# T00000251.nwk ,Gyrodactylus_cf._micropsi_1

		while($contents =~ s/([a-z]_)cf\._*([a-z])/$1$2/){};

		# T00000368.nwk: 0,Tetramolopium__humile:0.00
		while($contents =~ s/([A-Z][a-z]+_)_+([a-z]{2,})/$1$2/){};
	
		######################################################################################################################
		######################################################################################################################
		######################################################################################################################


		# get on to parsing taxa from terminal ids,
		# will start with ideally formatted ids,
		# and progressivly try to accomodate 'variation'
		# initially i tried to determine if trees contained multiple taxa, 
		# ie might be classed a species level phylogeny,
		# the data is far too messy to do this accurately,
		# so have simplified the criteria, to something that can be determined with reasonalbe accuracy
		# does the newick string contain readable taxonomic names in the terminal IDs
		# [and does it contain word variation]
		# nb, this aim of this project is certainly not to correct errors in the treehub data,
		# regardless of whether already in the files or introduced in the treehub pipeline,
		# this includes taxonomic casing error,
		# which to the uninitiated might seem strict, but is not due to the massive number and variety of components present.
		# the aim is: i make a reasonable effort to pick out what is most likely the taxonomic name in each terminal ID, 
		# then check if the string it is / is not in the taxonomic databases.


	

		my %binomials=();my %Taxa=();my %codes = ();


		my $current_tree_standard_binomials=0;
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_([a-z]{1,30})([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $species = $3; # my $binomial = $2; 
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			my $end = $3; 
			$binomials{$binomial}++;$current_tree_standard_binomials++; #	print "file:$file\t";

			};
		if($current_tree_standard_binomials >= 3)
			{
			$trees_standardized_binomials++;

			};


		# (Mus_musculus_MSM_phaplotype:0.00000,
		# for probable binomials, will split and check first item against tax database, for attached other words, will check each word item
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_([A-Z]+_[a-z]+)([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; # my $unlikely_name = $3; 
			my $end = $4; if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0,Mus_musculus_X14061Scheheemouse:0.000
		# contains a word within a code, word will be checked
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Z][0-9]+([A-Z][a-z]{1,30})([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (Mus_musculus_LakeBalhashmouse_w2haplotype:0.
		# check word items
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_([A-Z][a-z]+)([A-Z][a-z]{1,30})_\w[0-9]+(\w+)([\:\,\)])/$1$6/)
			{
			my $start = $1; my $genus = $2;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Mus_musculus_W1_w1haplotype:0.000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Z0-9]{1,2}_\w[0-9]+(\w+)([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $unlikely_name1 = $3;my $end = $4;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# Mus_musculus_BALBc_dhaplotype
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Z]{2,}\w_(\w+)([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $unlikely_name1 = $3; my $end = $4;
			$probable_binomials{$probable_binomial}++;$unlikely_names{$unlikely_name1}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# Mus_musculus_b1genew1
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_\w\d(\w+)\d*([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $unlikely_name1 = $3; my $end = $4; # 
			$probable_binomials{$probable_binomial}++;$unlikely_names{$unlikely_name1}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0,Gloxinia:0.000
		# probable genus name only, 
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# ,Scilla_bifolia_alliance:0
		# this format would normally be genus_species_subspecies
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[a-z]{1,30}([\:\,\)])/$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,'\'Scilla_monanthos\'':0.0
		# looks like a corruption of the single quoted terminal convention
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)_[a-z]+\\\'\'//)
			{
			my $genus = $1;  $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# '\'Scilla_sp.monanthosaff\''
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)_sp\.[a-z]+\\\'\'//)
			{
			my $genus = $1;  $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};



		# T00000183.nwk: ,(Eudesmia_group_2:0.0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_group_\d+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000189.nwk contents:(((((Leucostoma_cincta_24:0.0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[0-9\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Ophioceras_commune_CS408:0.0
		# should be the standard code format, uppercase letters followed by numbers, easy to differentiate
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Z]+[0-9\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Lulworthia_A202:0.0000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[A-Z]+[0-9\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (Thlaspi_perfoliatum_Germany:0.
		# 
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_([A-Z][a-z]{1,30})([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $unlikely_name = $3; my $end = $4; # $taxa{$taxon}=1;
			$probable_binomials{$probable_binomial}++;$unlikely_names{$unlikely_name}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (Thlaspi_BRA_CAE_CAL:0.000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[A-Z]{1,3}_[A-Z_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0.00000,Thlaspi_perfoliatum_Fr_Sw_Al
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Za-z]{1,2}_[A-Za-z]{1,2}_[A-Za-z]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ((Rudbeckia_sect._Macrocline:0.0
		# check both names
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,4}\._([A-Z][a-z]+)([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $taxon2 = $3; my $end = $4; $taxa{$taxon1}++;$taxa{$taxon2}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000216.nwk: (Bursera_brunea_clone11:0.00000,Burse
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_clone[A-Z0-9]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0.00000,Bursera_simarubaDR
		# not obvious what to do here, i think just checking the first name is the safe side
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{2,25}[A-Z]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2;  my $end = $3; $taxa{$taxon1}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};


		# ,Hemideina_maori_Rock_and_Pillar_Range_Y1:0.0
		# many subfields, unreasonable to expect taxa to be parsed, will check only first item
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_\w+_\w+_[A-Za-z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# Hemideina_maori_Crescent_Island
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]+_([A-Z][a-z]{3,25})_[A-Za-z_]+([\:\,\)])/$1$4/)
			{
			my $start = $1; my $genus = $2; my $taxon2 = $3; my $end = $4; $taxa{$taxon1}++;$taxa{$taxon2}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# still barely 200 files in, thus need to make regexes more general
		# ,Cryptococcus_neoformans_CPRalpha:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[A-Z]{2,}[A-Za-z0-9]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0.00000,Pleurotus_purpureo_olivaceous_D2342
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[a-z]{1,30}_[A-Za-z0-9]+([\:\,\)])/$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Desmarestia_sp.:0.00
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_sp\.*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# note some of these pattern matches will be superceeded by newer written ones placed earlier
		# )'\'Tenuiculus-Favoliporus\'':0.
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)\-[A-Za-z_]+\\\'\'//)
			{
			my $genus = $1; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000226.nwk ((Phyllariopsis_brevipes_ssp._brevipes:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[sp\.]+_[A-Za-z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (Sapria_P:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[A-Z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0,Peziza_polaripapulata1_3:0.0000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}\d_[A-Za-z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# )'\'P._polaripapulata-sp._4_lineage\'':0
		# breaks cardinal rule of phylogeny data, cannot be mapped
		while( $contents =~ s/\'\\\'[A-Z]\._[a-z\-\.0-9_]+\\\'\'//)
			{
		#	print "XXXXXXX file:$file";
			};

		# '\'Peziza_natrophila-quelepidotia_lineage\'':
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)[\-_][A-Za-z_\-]+\\\'\'//)
			{
			my $genus = $1; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ((Peziza_natrophila_1_2:0.000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (Erysiphe_pulchra_var._japonica_AB0159:0.00
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}_[a-zA-Z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0,Oidium_sp._AF154328:0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_sp\.*[A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# \'Hoffmannseggia_burchellii_ssp._rubro-violacea\'':0
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)[\-_][0-9A-Za-z_\-\.]+\\\'\'//)
			{
			my $genus = $1; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 00,CordyCeps_takaomontana:0.0
		# user error, which is impossible for curator to correct comprehensivly
		while( $contents =~ s/([\(\,])[A-Z][a-z]+[A-Z][a-z]+_[a-z]+([\:\,\)])/$1$2/)
			{
			};

		# T00000352.nwk ,l_quahog_parasite_QPX_1:0.0000
		# no formal taxonomic name to be found
		while( $contents =~ s/([\(\,])[a-z_]+_[A-Z0-9_]+([\:\,\)])/$1$2/)
			{
			};

		# T00000356.nwk: ,Asteraceae_QG_CA__Contig8140:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[A-Z]+_[A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 0)'\'PeloriusSchwartzius\'':0.
		# check first part
		while( $contents =~ s/\'\\\'([A-Z][a-z]+)[A-Z][0-9A-Za-z_\-\.]+\\\'\'//)
			{
			my $genus = $1; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# '\'fungal_polyketide_synthase_CR216-1\'':0.
		while( $contents =~ s/\'\\\'[a-z]+_[a-z_]+_[A-Za-z0-9\-]+\\\'\'//)
			{
			};


		# ((Acacia_Senegalia_schweinfurthii:0.000
		# check first name
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[A-Z][A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000407.nwk PxGV_Plutella_xylostella_granulovirus:0.0
		# complex with poorly formatted codes, pull out most likely genus name
		while( $contents =~ s/([\(\,])[A-Za-z]+[A-Z]_([A-Z][a-z]{1,30})_[A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 00,Cordyceps_capitata2:0.0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})_[a-z]{1,30}\d[A-Z0-9_]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $binomials{$binomial}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000468.nwk: ,Lambertella.subrenispora:0.00
		while( $contents =~ s/([\(\,])([A-Z][a-z]{1,30})\.[A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000478.nwk:(CBS112592Campylocarpon_pseudofasciculare:0.0
		while( $contents =~ s/([\(\,])[A-Z0-9]+[0-9]+([A-Z][a-z]{1,30})_[A-Za-z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00000494.nwk:(AleiodesJO659:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})[A-Z][A-Z0-9_\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (OdonTobracon:0.00
		# user error
		while( $contents =~ s/([\(\,])[A-Z][a-z]+[A-Z][a-z]+([\:\,\)])/$1$2/)
			{
			};

		# T00000543.nwk: ,Eopteria_cf._E._richardsoni:0.0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_cf\.[a-zA-Z0-9_\.]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# ,Crenoicus_n.sp.:0.0
		# 0.00000,Escarpiid_n._sp.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_n\._*sp\.*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_aff\.[a-zA-Z0-9_\.]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Boechera_658_clone3:
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_\d+[a-zA-Z0-9_\.]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		while( $contents =~ s/\'\\\'([A-Z][a-z]+)\\\'\'//)
			{
			my $genus = $1; $taxa{$taxon}++;if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# T00000614.nwk: (ATCC_50818:0.
		# codes only, skip
		while( $contents =~ s/([\(\,])([A-Z]+[_A-Z0-9]+)([\:\,\)])/$1$3/)
			{
			my $code = $2; $codes{$code}++; 
			};

		# T00000654.nwk ,xanthoparmelia_lithophiloides:0.
		# user error
		while( $contents =~ s/([\(\,])[a-z_]+([\:\,\)])/$1$2/)
			{
			};

		# T00000717.nwk ,_AY725517:0
		# looks like ncbi accession only
		while( $contents =~ s/([\(\,])([_A-Z0-9]+)([\:\,\)])/$1$3/)
			{
		#	my $code = $2; $codes{$code}++

			};

		# T00000757.nwk: sister_clade_to_Volvariella_122a_03
		# pick out most likely name
		while( $contents =~ s/([\(\,])[a-z_]+_([A-Z][a-z]{3,30})_\d+[a-zA-Z0-9_\.]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		#00,crepidotus_045a_12:0.
		# user case error
		while( $contents =~ s/([\(\,])[a-z_]+_[a-z0-9_\.]*([\:\,\)])/$1$2/)
			{
			};

		# 0000,LachnellaCalathella_027a_10:0.00000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})[A-Z][a-z]+_[a-zA-Z0-9_\.]*([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};
		
		# T00001934.nwk:((B06_Guaymas:0
		while( $contents =~ s/([\(\,])[A-Z0-9]+_([A-Z][a-z]{3,30})([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		while( $contents =~ s/([\(\,])[a-z_]+_[a-z0-9_\.]+_[A-Za-z0-9]+([\:\,\)])/$1$2/)
			{
			};

		# T00000874.nwk((Pyrrhobryum_com.:
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z]+\.([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# T00000884.nwk:acutNP09:0.
		# meaningless codes
		while( $contents =~ s/([\(\,])([a-z_]+[A-Z]+\d+[_A-Za-z0-9]*)([\:\,\)])/$1$3/)
			{
			};

		# (Tiquilia_gossypina.134:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z]+\.[\d\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# Tiquilia_purpusii.JPS:0.0
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z]+\.[a-zA-Z0-9\.]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree++};
			};

		# informal names, poor practice
		# T00000897.nwk )'\'blue-flowered_South_American_Tiquilia\'':
		while( $contents =~ s/\'\\\'[a-z]+\-[a-z]+_[_A-Za-z0-9]+\\\'\'//)
			{
			};

		# ,Neptune2_ex_Reniera_sp_JGI2005:0.
		while( $contents =~ s/([\(\,])[\w\d]+_ex_([A-Z][a-z]{3,30})_[A-Za-z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		#T00000971.nwk (uncultured_Glomus_AY236282:0.00
		while( $contents =~ s/([\(\,])[a-z]+_([A-Z][a-z]{3,30})_[A-Za-z0-9_]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# T00001031.nwk ,HIbiscus_ferrugineus:0.00000)
		# casing error
		while( $contents =~ s/([\(\,])[A-Z][A-Z][a-z]+_[a-z]+([\:\,\)])/$1$2/)
			{
			};

		# 0.00000,AAeluropus
		while( $contents =~ s/([\(\,])[A-Z][A-Z][a-z]+([\:\,\)])/$1$2/)
			{
			};

		# T00001101.nwk ,Beschorneria_yuccoidesTur:0.00000):0.0000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z]+[A-Z]\w+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# 00,Eragrostis_s._E:0.0000
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z][A-Z\._]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# (D_phaseolorum_v_caulivora_AF000563:0.000
		# presumably abbreviated genus name, poor practice
		while( $contents =~ s/([\(\,])[A-Z]_[a-z]+_[a-z_]+[A-Z0-9]+([\:\,\)])/$1$2/)
			{
			};

		# 0.00000,Pleione_hookeriana406India
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z]+\d+\w+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# ,Inuleae_s._str.:0.
		while( $contents =~ s/([\(\,])([A-Z][a-z]{3,30})_[a-z\._]+([\:\,\)])/$1$3/)
			{
			my $start = $1; my $genus = $2; my $end = $3; # $taxa{$taxon}++;
			if($taxnames{$genus} == 1){$mapped_tax_current_tree2++};
			};

		# at this point, extracting all taxon names out of about 8/10 files
		while( $contents =~ s/([\(\,])([0-9]+)([\:\,\)])/$1$3/)
			{
			};

		my @binom_keys = keys %binomials; my @tax_keys = keys %Taxa;
		

				
		if($#binom_keys >= 3 || $#tax_keys >= 3 )
			{
		#	print "\nbinom_keys:@binom_keys tax_keys:@tax_keys\t";
			$count6++};

		######################################################################################################################
		######################################################################################################################
		######################################################################################################################

		# note $mapped_tax_current_tree >= 4 means 4 or more terminals have a valid taxonomic name, NOT 4 or more names are present
		if($mapped_tax_current_tree >= 4 && $current_tree_standard_binomials >= 4)
			{
			$trees_with_mapped_taxa++;

			# one thing i want to know is the source of the standard formatted trees (the more useful class).
			if( $whichtreetype{$filename_only} =~ /./)
				{
				if($whichstudyID{$filename_only} =~ /./)
					{
					my $currenttree_studyID = $whichstudyID{$filename_only};
					$source_of_standard_newicks{$currenttree_studyID} = $whichtreetype{$filename_only};
					if($whichtreetype{$filename_only} =~ /crawl/){
					#	print "TH contribution:$filename_only\t$whichstudyID{$filename_only}\n"
						};
					};

				}else{
			#	$source_of_standard_newicks{"unknown_source"}++;
				};


			}else{

			# current tree not strictly formatted and with mapped names,
			# but, does it contain some successfully extracted words confirmed as tax names
			if($mapped_tax_current_tree2 >= 4)
				{
				$trees_with_mapped_taxa2++;
				if( $whichtreetype{$filename_only} =~ /./)
					{
					if($whichstudyID{$filename_only} =~ /./)
						{
						my $currenttree_studyID = $whichstudyID{$filename_only};
						$source_of_nonstandard_newicks{$currenttree_studyID} = $whichtreetype{$filename_only};
						};

				}
				};
			
			};




		$fileparse_counter++;
		if( $contents =~ /[A-Z][a-z]{3,}/)
			{
		#	print "file:$file contents:$contents\n"; 
				
	#		unless($contents =~ /Thysanolaena|symbiont_of_|ypella__Cipura|Outgroup_to_Onagraceae|Dunaliella_parva|Ophiostoma_s/){ die""};

		# 0,symbiont_of_Lasioderma_serricor:0.000

			$filenotparsed++;
			}else{
			$fileparsed++;
				
			};

		if($fileparse_counter =~ /000$/)
			{print "$fileparse_counter, fileparsed:$fileparsed filenotparsed:$filenotparsed files w any name parses:$count6\n"};

		######################################################################################################################


		}else{
		# no nested parentheses in current file	
		$no_nested_parentheses++;

		# files in this section have no next parentheses,
		# following pattern matching section checks what exactly they are,
		# to make sure no alternative tree formats are overlooked 
				
	#	$contents =~ s/^\[\&[UR]\]\s+//; # remove root assignment from newick start if present

		if($contents =~ /^\([A-Za-z\_\:0-9\.]+\)\:0\.0+\;/)
			{
			# Newick string with single branch / single terminus
			# (Fuirena_simplex:0.00000):0.00000;
			$only_one_branch++;
			}elsif($contents =~ /^\(\d+\:[0-9\.]+\,\d+\:[0-9\.]+\)\;/)
			{
			# e.g. (578:0.07858492818,579:0.07858492818);
			# single split, no tax names
			$only_one_split++;if($contents =~ /[A-Z]i/){die "\nparse error\n"};
			}elsif($contents =~ /^\([^\,\(\)]+\)\:[0-9\.]+\;/)
			{
			# single branch
			# e.g. (Eqca|NC_0091532_22443492_22442574):0.452076;
			$only_one_branch++;
			}elsif($contents =~ /^[0-9\.]+\;/)
			{
			# no tree components, just some number
			# e.g. 732759526326806;
			$some_number++;
			}elsif($contents =~ /^\([^\(\)]+\)[A-Za-z0-9\.\:]{0,50}\;/)
			{
			# single comb only
			# e.g. (Vaccinium_macrocarpon,Cynomorium_coccineum,Hamamelis_virginiana);
			$single_comb_only++;
			}elsif($contents =~ /./)
			{
			# no entries matching this
			}else{
			# should be none of these due to already within condidiotnal for file size>0 
			};
		
		}; # if($contents =~ /\(.*\(.*\).*\)/){}else{

		

	}; # if($newick_delimitor==1){ # virtually all non empty files have single newick

	};# file size not zero

	$file_index++;if($file_index =~ /0000$/){print "$file_index of $#file_list\n"};


	}; # foreach my $file(@file_list)

print "
counts:
	empty files:		$empty_files
	single_newicks:	$single_newicks
	parentheses:		$parentheses
	no_nested_parentheses:	$no_nested_parentheses
	only_one_branch:	$only_one_branch
	only_one_split:   	$only_one_split
	single_comb_only:	$single_comb_only
	some_number:		$some_number
	phylogenies:		$phylogenies
	treelike:		$treelike
	root_status:		$root_status
	no_root_status:	$no_root_status
	nexus_files:		$nexus_files


parenth:				$parenth
commas:				$commas
outliers:				$outliers
trees_with_coded_terminals:		$trees_with_coded_terminals
single_quoted:				$single_quoted
trees_treehub_quoted:			$trees_treehub_quoted
trees_single_quoted:			$trees_single_quoted
trees_standardized_binomials:		$trees_standardized_binomials
trees_with_mapped_taxa (strict):	$trees_with_mapped_taxa
trees_with_mapped_taxa2 (fuzzy):	$trees_with_mapped_taxa2

type1:		$type1
type2 (\"):	$type2
type3 (-):	$type3
type4 (+):	$type4
type5 (/):	$type5
type6 (*):	$type6
type7 (=):	$type7
type8 (?):	$type8
type9 ({}):	$type9
type10 ({):	$type10
type11 (\#):	$type11
type12 ((,)):	$type12
type13 (&):	$type13
type14 ([]):	$type14
type15 (:):	$type15

";

my @studyID_keys = keys %source_of_standard_newicks;@studyID_keys=sort @studyID_keys;
foreach my $key(@studyID_keys)
	{
	my $type = $source_of_standard_newicks{$key};$type_counts{$type}++;
#	print "$key\t$source_of_standard_newicks{$key}\n";

	};
print "\nsources of standard newickes\n";

my @type_keys = keys %type_counts;
foreach my $key(@type_keys)
	{
	print "$key: $type_counts{$key}\n";
	};



my @studyID_keys = keys %source_of_nonstandard_newicks;@studyID_keys=sort @studyID_keys;
foreach my $key(@studyID_keys)
	{
	my $type = $source_of_nonstandard_newicks{$key};$type_counts2{$type}++;
#	print "$key\t$source_of_standard_newicks{$key}\n";

	};
print "\nsources of non standard newickes\n";
my @type_keys2 = keys %type_counts2;
foreach my $key(@type_keys2)
	{
	print "$key: $type_counts2{$key}\n";
	};







}; # sub parse_treefiles



##########################################################################################################################
##########################################################################################################################
##########################################################################################################################


sub parse_ncbi_tax_database
{


open(NAMES, "$ncbi_tax_database_path") || die "

path give:$ncbi_tax_database_path

cant open names.dmp
go to ftp://ftp.ncbi.nih.gov/pub/taxonomy/\nget the file taxdump.tar.gz\nunzip and place in working directory
then write the correct path in current script
\nquitting.\n";


print "\nnames.dmp, parsing 'scientific name', ignoring others ... ";

my $names_line_counter=0;
while (my $line = <NAMES>)
	{
# 24	|	Shewanella putrefaciens	|		|	scientific name	|

	if($line =~ /^(\d+)\t[\|]\t([^\t]+)\t[\|]\t([^\t]*)\t[\|]\tscientific name/)
		{
		my $tax_id = $1;my $name = $2; my $rank = $3; # print "tax_id:$tax_id rank:$rank name:$name\n";
		# if you want to remove non-alphanumerical characters from assigned species names:
	#	$name =~ s/[\(\)\,\[\]\'\#\&\/\:\.\-]/ /g;
	#	$name =~ s/\s\s+/ /g;$name =~ s/\s+$//;$name =~ s/^\s+//;
	#	$ncbi_nodes{$tax_id}{name} = $name;
	#	$names_line_counter++;#print "$names_line_counter\n";
		if($name =~ /^[A-Z][a-z]{2,25}$/){$taxnames{$name}=1;$ncbi_taxnames_stored++};
		}else{
		if($line =~ /^(\d+).+scientific name/){die "UNEXPECTED LINE:\n$line\nquitting\n"}
		}
	}
close(NAMES);
print "\nncbi_taxnames_stored:$ncbi_taxnames_stored\n";

}; # sub parse_ncbi_tax_database


##########################################################################################################################
##########################################################################################################################
##########################################################################################################################

sub parse_catalogue_of_life
{
print "\nchecking for catalogue of life at path given:$catalogue_of_life_path\n";
open(COL_D , $catalogue_of_life_path) || print "\nwarning, cant open the catalogue of life taxonomic database.\n";
while (my $line = <COL_D>)
	{
	#                        Melozone Reichenbach, 1850 [genus]
	if($line =~ /^\s+([A-Z][a-z]{2,30})\s.+\[genus\]/)
		{
		my $COL_genus = $1;$taxnames{$COL_genus}=1;$COL_counter++;
		};
	};
print "Catalogue of Life counter:$COL_counter\n";
};


##########################################################################################################################
##########################################################################################################################
##########################################################################################################################

sub read_treetypes
{

my $treetypes_table = "study_details_parsed.tdt";
open(TREETYPE_TABLE, $treetypes_table) || print "\ntree type table (study_details_parsed.tdt) not found, ignoring.\n";
while(my $line = <TREETYPE_TABLE>)
	{
	# this file has tree type (mostly treebase or crawl) for each treeID
#	print "$line";	
	if($line =~ /^(T\d+\.nwk)\t(\S+)\t(\S+)\t/)
		{
		my $th_treeID = $1; my $th_studyID = $2;my $th_treetype = $3;
		$whichtreetype{$th_treeID}=$th_treetype;$treetypes_read++;
		$whichstudyID{$th_treeID}=$th_studyID;
		# store in a has keyed with treehub treeID, to be read later.
		# print "ID:$th_treeID\ttype:$th_treetype\n";

		};

	};
close TREETYPE_TABLE;

print "
from  file $treetypes_table, treetypes_read:$treetypes_read
";
# die "";

};

##########################################################################################################################
##########################################################################################################################
##########################################################################################################################








