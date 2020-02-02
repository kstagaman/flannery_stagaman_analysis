# Color blind palettes
getCB.pal <- function(x) {
    if(x == "gray" | x == "grey" | x == "g" | x == 1) {
        cb.pal <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
        names(cb.pal) <- c("gray", "orange", "sky_blue", "green", "yellow", "blue", "red", "pink")
    } else if(x == "black" | x == "b" | x == 2) {
        cb.pal <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
        names(cb.pal) <- c("black", "orange", "sky_blue", "green", "yellow", "blue", "red", "pink")
    }
    return(cb.pal)
}


