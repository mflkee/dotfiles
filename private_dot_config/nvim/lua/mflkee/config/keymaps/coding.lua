-- Code chunk insertion.
vim.keymap.set({ "i", "n" }, "<m-i>", "<esc>i```{python}<cr>```<esc>O", { desc = "[I]nsert code chunk" })
vim.keymap.set("n", "<leader>ci", ":split term://ipython<cr>", { desc = "Split terminal (ipython)" })

local function term_exec(cmd, cwd)
	local ok, toggleterm = pcall(require, "toggleterm")
	if not ok then
		vim.notify("toggleterm.nvim is not available", vim.log.levels.ERROR)
		return
	end

	toggleterm.exec(cmd, nil, nil, cwd)
end

local function find_package_root(start_dir)
	local package_json = vim.fs.find("package.json", {
		upward = true,
		path = start_dir,
	})[1]

	if package_json then
		return vim.fs.dirname(package_json)
	end

	return start_dir
end

local function resolve_node_runner(start_dir, candidates)
	local root = find_package_root(start_dir)

	for _, candidate in ipairs(candidates) do
		local local_bin = root .. "/node_modules/.bin/" .. candidate
		if vim.fn.executable(local_bin) == 1 then
			return vim.fn.shellescape(local_bin), root
		end
	end

	for _, candidate in ipairs(candidates) do
		if vim.fn.executable(candidate) == 1 then
			return candidate, root
		end
	end

	return nil, root
end

local function run_current_file()
	local filetype = vim.bo.filetype
	local current_file = vim.fn.expand("%:p")
	local dir = vim.fn.expand("%:p:h")
	local shellescaped_file = vim.fn.shellescape(current_file)

	local function run_with_node()
		term_exec("node " .. shellescaped_file, dir)
	end

	local function run_with_tsx()
		local runner, cwd = resolve_node_runner(dir, { "tsx" })
		if not runner then
			vim.notify("TypeScript runner not found. Install `tsx` globally or in the project.", vim.log.levels.WARN)
			return
		end

		term_exec(runner .. " " .. shellescaped_file, cwd)
	end

	local function run_with_transpiler()
		local runner, cwd = resolve_node_runner(dir, { "tsx", "ts-node" })
		if not runner then
			vim.notify("JSX/TS runner not found. Install `tsx` (preferred) or `ts-node`.", vim.log.levels.WARN)
			return
		end

		term_exec(runner .. " " .. shellescaped_file, cwd)
	end

	local runners = {
		rust = function()
			term_exec("cargo run", dir)
		end,
		python = function()
			term_exec("python " .. shellescaped_file)
		end,
		javascript = run_with_node,
		typescript = run_with_tsx,
		javascriptreact = run_with_transpiler,
		typescriptreact = run_with_transpiler,
		quarto = function()
			vim.cmd("QuartoPreview")
		end,
		cpp = function()
			local output_file = vim.fn.expand("%:p:r")
			local compile_and_run = string.format(
				"g++ -o %s %s && %s",
				vim.fn.shellescape(output_file),
				shellescaped_file,
				vim.fn.shellescape(output_file)
			)
			term_exec(compile_and_run, dir)
		end,
	}

	local runner = runners[filetype]
	if runner then
		runner()
	else
		vim.notify("Unsupported filetype: " .. filetype, vim.log.levels.WARN)
	end
end

-- Run code by filetype.
vim.keymap.set("n", "<leader>R", run_current_file, { desc = "[R]un code based on filetype" })
vim.keymap.set("n", "<D-S-r>", run_current_file, { desc = "[R]un code based on filetype" })
