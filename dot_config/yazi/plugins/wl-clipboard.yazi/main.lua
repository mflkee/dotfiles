local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

local mime_map = {
	png = "image/png",
	jpg = "image/jpeg",
	jpeg = "image/jpeg",
	gif = "image/gif",
	webp = "image/webp",
	svg = "image/svg+xml",
	bmp = "image/bmp",
	ico = "image/x-icon",
	tiff = "image/tiff",
	tif = "image/tiff",
	avif = "image/avif",
	pdf = "application/pdf",
	txt = "text/plain",
	md = "text/markdown",
	csv = "text/csv",
	json = "application/json",
	html = "text/html",
	htm = "text/html",
	css = "text/css",
	js = "text/javascript",
	ts = "text/typescript",
	py = "text/x-python",
	rs = "text/x-rust",
	lua = "text/x-lua",
	sh = "text/x-shellscript",
	toml = "text/x-toml",
	yaml = "text/x-yaml",
	yml = "text/x-yaml",
	xml = "text/xml",
	log = "text/plain",
}

local function get_mime(path)
	local ext = path:match("%.([^%.]+)$")
	if ext then
		ext = ext:lower()
		if mime_map[ext] then
			return mime_map[ext]
		end
	end
	return "application/octet-stream"
end

return {
	entry = function()
		ya.emit("escape", { visual = true })

		local urls = selected_or_hovered()

		if #urls == 0 then
			return ya.notify({ title = "Clipboard", content = "No file selected", level = "warn", timeout = 5 })
		end

		local path = urls[1]
		local mime = get_mime(path)
		local escaped = path:gsub("'", "'\\''")

		local status, err = Command("sh"):arg("-c")
			:arg(string.format("wl-copy --type '%s' < '%s'", mime, escaped))
			:spawn():wait()

		if status and status.success then
			ya.notify({
				title = "Clipboard",
				content = "Copied as " .. mime,
				level = "info",
				timeout = 5,
			})
		else
			ya.notify({
				title = "Clipboard",
				content = "Failed: " .. tostring(status and status.code or err),
				level = "error",
				timeout = 5,
			})
		end
	end,
}
