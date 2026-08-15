--- @sync entry

local DT = (os.getenv("HOME") or "") .. "/.config/scripts/utils/dt.sh"

local function collect(job)
	local selected, urls = cx.active.selected, {}
	if #selected > 0 then
		for _, f in ipairs(selected) do
			urls[#urls + 1] = f.url
		end
	else
		local h = cx.active.current.hovered
		if h then
			urls[1] = h.url
		end
	end
	return urls
end

local function confirm(urls)
	local lines = {
		ui.Line(string.format("%d item(s) will be moved to trash:", #urls)):style(th.confirm.body or th.confirm.content),
		ui.Line(""),
	}
	for _, u in ipairs(urls) do
		lines[#lines + 1] = ui.Line { "  ", ui.Span(tostring(u)) }
	end

	return ya.confirm {
		pos = { "center", w = 90, h = math.min(#urls + 6, 30) },
		title = ui.Line("Move to trash (dt)"):style(th.confirm.title),
		body = ui.Text(lines):wrap(ui.Wrap.YES),
	}
end

return {
	entry = function(_, job)
		local urls = collect(job)
		if #urls == 0 then
			return ya.notify { title = "dt", content = "Nothing to trash", level = "warn", timeout = 3 }
		end

		if not job.args.quick and not confirm(urls) then
			return
		end

		ya.emit("shell", { DT .. " %S", confirm = false })
		ya.emit("refresh", {})
	end,
}
