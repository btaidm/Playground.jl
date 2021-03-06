# currently only creates a symlink
function mklink(src::AbstractString, dest::AbstractString; soft=true, overwrite=true)
    if ispath(src)
        if ispath(dest) && soft && overwrite
            rm(dest, recursive=true)
        end

        if !ispath(dest)
            @unix_only begin
                run(`ln -s $(src) $(dest)`)
            end
            @windows_only begin
                if isfile(src)
                    run(`mklink $(dest) $(src)`)
                else
                    run(`mklink /D $(dest) $(src)`)
                end
            end
        elseif !soft
            error("$(dest) already exists.")
        end
    else
        error("$(src) is not a valid path")
    end
end


function copy(src::AbstractString, dest::AbstractString; soft=true, overwrite=true)
    if ispath(src)
        if ispath(dest) && soft && overwrite
            rm(dest, recursive=true)
        end

        if !ispath(dest)
            # Shell out to copy directories cause this isn't supported
            # in v0.3 and I don't feel like copying all of that code into this
            # project. This if should be deleted when 0.3 is deprecated
            cp(src, dest)
        elseif !soft
            error("$(dest) already exists.")
        end
    else
        error("$(src) is not a valid path")
    end
end


@doc doc"""
    We overload download for our tests in order to make sure we're just download. The
    julia builds once.
""" ->
function Base.download(src::AbstractString, dest::AbstractString, overwrite)
    if !ispath(dest) || overwrite
        download(src, dest)
    end
    return dest
end


function get_playground_dir(config::Config, dir::AbstractString, name::AbstractString)
    if dir == "" && name == ""
        return abspath(joinpath(pwd(), config.default_playground_path))
    elseif dir == "" && name != ""
        return abspath(joinpath(config.dir.store, name))
    elseif dir != ""
        return abspath(dir)
    end
end


function get_playground_name(config::Config, dir::AbstractString)
    root_path = abspath(dir)
    name = ""

    for p in readdir(config.dir.store)
        file_path = joinpath(config.dir.store, p)
        if islink(file_path)
            if abspath(readlink(file_path)) == root_path
                name = p
                break
            end
        end
    end

    return name
end


function get_julia_dl_url(version::VersionNumber, config::Config)
    tmp_download_page = joinpath(config.dir.tmp, "julia-downloads.html")

    if isfile(tmp_download_page)
        delta = Dates.today() - Dates.Date(Dates.unix2datetime(stat(tmp_download_page).mtime))
        if delta.value > 0
            rm(tmp_download_page)
            download(JULIA_DOWNLOADS_URL, tmp_download_page)
        end
    else
        download(JULIA_DOWNLOADS_URL, tmp_download_page)
    end

    txt = open(readall, tmp_download_page)
    lines = split(txt, "\n")

    platform = "N/A"
    if OS_NAME===:Windows
        platform = "win64"
    elseif OS_NAME===:Linux
        platform = "linux-x86_64"
    elseif OS_NAME===:Darwin
        platform = "osx"
    end

    links = []

    for line in lines
        m = match(r"(?i)<a href=\"([^>]+)\">(.+?)</a>", line)
        if m != nothing && contains(m.captures[1], platform)
            link = m.captures[1]
            if version < NIGHTLY
                if contains(link, "$(version.major).$(version.minor)")
                    push!(links, link)
                end
            else
                if contains(link, "status.julialang.org")
                    push!(links, link)
                end
            end
        end
    end

    if length(links) != 1
        error("Expected 1 valid link, got $(length(links)). $links")
    end

    return links[1]
end
