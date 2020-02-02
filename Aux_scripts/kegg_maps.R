# kegg_maps.R

# This script links kos, modules, and pathways using the KEGGREST package and then creates
# tables you can use to map them to each other.
require(KEGGREST)
require(phyloseq)
require(parallel)
stool1.kos.phy <- readRDS(file.path(saveDir, "phyloseq_stool1_kos.rds"))

my.kos <- taxa_names(stool1.kos.phy)
my.kos.df <- data.frame("ko"=my.kos, stringsAsFactors=FALSE)
list.kos <- keggList("ko")
df.kos <- data.frame(
    "ko"=gsub("ko:", "", names(list.kos)),
    "ko.name"=list.kos,
    stringsAsFactors=F
)
row.names(df.kos) <- df.kos$ko

link.kos.mod <- keggLink("module", "ko")
list.mod <- keggList("module")
list.mod <- gsub("'", "′", list.mod)
df.mod <- data.frame(
    "module"=gsub("md:", "", names(list.mod)),
    "module.name"=list.mod,
    stringsAsFactors=FALSE
)
saveRDS(df.mod, file=file.path(saveDir, "kegg_mod_names.rda"))
df.kos.mod <- data.frame(
    "ko"=gsub("ko:", "", names(link.kos.mod)),
    "module"=gsub("md:", "", link.kos.mod),
    stringsAsFactors=FALSE
)
# map.kos.mod <- merge(
#     my.kos.df,
#     merge(df.kos.mod, df.mod, by="module", all=TRUE),
#     by="ko",
#     all=TRUE
# )
map.kos.mod <- merge(
    merge(my.kos.df, df.kos, by="ko", all=TRUE),
    merge(df.kos.mod, df.mod, by="module", all=TRUE),
    by="ko",
    all=TRUE
)
saveRDS(map.kos.mod, file=file.path("Static_data", "map_kos_mod.rds"))

# link.kos.path <- keggLink("pathway", "ko")
# list.path <- keggList("pathway")
# list.path <- gsub("'", "", list.path)
# df.path <- data.frame(
#     "pathway"=gsub("path:", "", names(list.path)),
#     "pathway.name"=list.path,
#     stringsAsFactors=FALSE
# )
# saveRDS(df.path, file=file.path(saveDir, "kegg_path_names.rda"))
# df.kos.path <- data.frame(
#     "ko"=gsub("ko:", "", names(link.kos.path)),
#     "pathway"=gsub("path:", "", link.kos.path),
#     stringsAsFactors=FALSE
# )
# df.kos.path <- subset(df.kos.path, grepl("map", pathway))
# map.kos.path <- merge(
#     my.kos.df,
#     merge(df.kos.path, df.path, by="pathway", all=TRUE),
#     by="ko",
#     all=TRUE
# )
# save(map.kos.path, file=file.path(saveDir, "map_kos_path.rda"))
#
# map.kos.mod.path <- merge(map.kos.mod, map.kos.path, by="ko", all=TRUE)
# save(map.kos.mod.path, file=file.path(saveDir, "map_kos_mod_path.rda"))

nCores <- floor(detectCores() * 3/4)
cl <- makeCluster(nCores, type="FORK")

# my.kos.paths.clpsd <- data.frame(
#     "ko"=my.kos,
#     "pathways"=parSapply(cl, my.kos,
#                          FUN=function(x) paste(subset(map.kos.path, ko==x)$pathway,
#                                                collapse="; ")),
#     "pathways.names"=parSapply(cl, my.kos,
#                                FUN=function(x) paste(subset(map.kos.path, ko==x)$pathway.name,
#                                                      collapse="; ")),
#     stringsAsFactors=FALSE
# )
# save(my.kos.paths.clpsd, file=file.path(saveDir, "my_kos_paths_clpsd.rda"))

my.kos.mods.clpsd <- data.frame(
    "ko"=my.kos,
    "ko.name"=df.kos[my.kos, "ko.name"],
    "modules"=parSapply(cl, my.kos,
                        FUN=function(x) paste(subset(map.kos.mod, ko==x)$module,
                                              collapse="; ")),
    "modules.names"=parSapply(cl, my.kos,
                              FUN=function(x) paste(subset(map.kos.mod, ko==x)$module.name,
                                                    collapse="; ")),
    stringsAsFactors=FALSE
)
stopCluster(cl)

saveRDS(my.kos.mods.clpsd, file=file.path("Static_data", "my_kos_mods_clpsd.rds"))
writeLines(sort(subset(my.kos.mods.clpsd, modules == "NA")$ko), "no_module_kos.txt")
