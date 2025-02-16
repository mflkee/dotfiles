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

		require("mason-nvim-dap").setup({
			automatic_setup = true,
			handlers = {},
			ensure_installed = {
				"delve",
				"cppdbg",
			},
		})

		-- Новые хоткеи через <leader>
		vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Start/Continue" })
		vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
		vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over" })
		vim.keymap.set("n", "<leader>du", dap.step_out, { desc = "Debug: Step Out" })
		vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
		vim.keymap.set("n", "<leader>dB", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Debug: Set Conditional Breakpoint" })
		vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Debug: Restart" })
		vim.keymap.set("n", "<leader>ds", dap.stop, { desc = "Debug: Stop" })
		vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "Debug: Pause" })
		vim.keymap.set("n", "<leader>dn", dap.run_to_cursor, { desc = "Debug: Run to Cursor" })

		-- Настройка Dap UI
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
					terminate = "",
					disconnect = "⏏",
				},
			},
		})

		-- Настройка адаптера для C++
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
					-- Получаем путь к текущему файлу без расширения
					local executable = vim.fn.expand("%:p:r") -- Убираем расширение .cpp
					-- Компилируем файл с флагом -g
					local compile_command = "g++ -g " .. vim.fn.expand("%:p") .. " -o " .. executable
					local success, result = os.execute(compile_command)
					if not success then
						vim.notify("Compilation failed: " .. result, vim.log.levels.ERROR)
						return nil
					end
					return executable
				end,
				cwd = "${workspaceFolder}",
				stopAtEntry = true,
				MIDebuggerPath = "/usr/bin/gdb", -- Убедитесь, что путь к GDB правильный
				setupCommands = {
					{
						text = "-enable-pretty-printing",
						description = "Enable pretty printing",
						ignoreFailures = false,
					},
				},
			},
		}

		-- Открыть/закрыть UI дебаггера
		vim.keymap.set("n", "<leader>dt", dapui.toggle, { desc = "Debug: Toggle Debug UI" })

		-- Автоматически открывать/закрывать UI при старте/завершении отладки
		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close

		-- Настройка Go-отладчика (если нужно)
		require("dap-go").setup()
	end,
}
