---@diagnostic disable: undefined-global
return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",
		"leoluz/nvim-dap-go",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		-- Setup mason-nvim-dap to install debuggers
		require("mason").setup()
		require("mason-nvim-dap").setup({
			automatic_setup = true,
			ensure_installed = {
				"delve", -- Go
				"cppdbg", -- C++
				"debugpy", -- Python
				"codelldb", -- Rust
			},
		})

		-- Configure dap-ui
		dapui.setup({
			icons = { expanded = "", collapsed = "", current_frame = "" },
			controls = {
				icons = {
					pause = "",
					play = "",
					step_into = "",
					step_over = "",
					step_out = "",
					step_back = "",
					run_last = "",
					terminate = "⏏",
					disconnect = "⏏",
				},
			},
		})

		-- C++ adapter
		dap.adapters.cppdbg = {
			id = "cppdbg",
			type = "executable",
			command = vim.fn.stdpath("data") .. "/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
		}

		dap.configurations.cpp = {
			{
				name = "Launch file",
				type = "cppdbg",
				request = "launch",
				program = function()
					local exe = vim.fn.expand("%:p:r")
					vim.fn.system({ "g++", "-g", vim.fn.expand("%:p"), "-o", exe })
					return exe
				end,
				cwd = "${workspaceFolder}",
				stopAtEntry = true,
				MIDebuggerPath = "/usr/bin/gdb",
				setupCommands = {
					{
						text = "-enable-pretty-printing",
						description = "Enable pretty printing",
						ignoreFailures = false,
					},
				},
			},
		}

		-- Python adapter
		dap.adapters.python = {
			type = "executable",
			command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
			args = { "-m", "debugpy.adapter" },
		}

		dap.configurations.python = {
			{
				type = "python",
				request = "launch",
				name = "Launch file",
				program = "${file}",
				pythonPath = function()
					return vim.fn.trim(vim.fn.system("which python3"))
				end,
				cwd = "${workspaceFolder}",
				console = "integratedTerminal",
				stopOnEntry = false,
			},
			{
				type = "python",
				request = "launch",
				name = "Launch module",
				module = function()
					return vim.fn.input("Enter module name: ")
				end,
				pythonPath = function()
					return vim.fn.trim(vim.fn.system("which python3"))
				end,
				cwd = "${workspaceFolder}",
				console = "integratedTerminal",
				stopOnEntry = false,
			},
		}

		-- Rust adapter via codelldb
		local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
		dap.adapters.codelldb = {
			type = "server",
			port = "${port}",
			executable = {
				command = mason_path .. "/extension/adapter/codelldb",
				args = { "--port", "${port}" },
			},
		}

		dap.configurations.rust = {
			{
				name = "Launch Rust",
				type = "codelldb",
				request = "launch",
				program = function()
					-- Build and return the path to the executable
					vim.cmd("!cargo build")
					local metadata = vim.fn.systemlist("cargo metadata --format-version 1 --no-deps")[1]
					local decoded = vim.fn.json_decode(metadata)
					local target_dir = decoded.target_directory
					local pkg = decoded.packages[1].name
					return target_dir .. "/debug/" .. pkg
				end,
				cwd = "${workspaceFolder}",
				stopOnEntry = false,
				args = {},
			},
		}

		-- Go adapter (via delve)
		require("dap-go").setup()

		-- Keymaps for DAP
		local map = vim.keymap.set
		map("n", "<leader>dc", dap.continue, { desc = "Debug: Continue" })
		map("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
		map("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over" })
		map("n", "<leader>du", dap.step_out, { desc = "Debug: Step Out" })
		map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
		map("n", "<leader>dB", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Debug: Set Conditional Breakpoint" })
		map("n", "<leader>dr", dap.restart, { desc = "Debug: Restart" })
		map("n", "<leader>ds", dap.stop, { desc = "Debug: Stop" })
		map("n", "<leader>dp", dap.pause, { desc = "Debug: Pause" })
		map("n", "<leader>dn", dap.run_to_cursor, { desc = "Debug: Run to Cursor" })
		map("n", "<leader>dt", dapui.toggle, { desc = "Debug: Toggle UI" })

		-- Auto open/close UI
		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close
	end,
}
