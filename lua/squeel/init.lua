M = {}

local function file_exists(path)
	local stat = vim.loop.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return false
	end

	return true
end

local function is_executable(path)
	if not file_exists(path) then
		return false
	end
	return vim.fn.executable(path) == 1
end

local function find_python(path)
	local output = ""
	if path ~= nil then
		if is_executable(path) then
			output = path
		end
	else
		if vim.fn.executable("python3") == 1 then
			output = "python3"
		elseif vim.fn.executable("python") == 1 then
			output = "python"
		else
			error("SQUEEL: Python is not available. Please install Python and try again.")
		end
	end

	return output
end

local function venv_executable_path(venv_path)
	if not venv_path then
		error("SQUEEL: Virtual environment path is required.")
	end

	local python_executable
	if vim.loop.os_uname().sysname == "Windows_NT" then
		python_executable = venv_path .. "\\Scripts\\python.exe"
	else
		python_executable = venv_path .. "/bin/python"
	end

	if not is_executable(python_executable) then
		error("SQUEEL: No python executable found in venv " .. venv_path)
	end

	return python_executable
end

local validate_python = function(python)
	print("SQUEEL: Validating python version...")
	local output = vim.fn.system(python .. " --version"):gsub("%s+$", "")
	local version = output:match("Python%s+([%d%.]+)")
	if not version then
		error("The python version found is invalid")
	end

	local major, minor, patch = version:match("^(%d+)%.(%d+)%.?(%d*)$")
	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch) or 0

	if not (major > 3 or (major == 3 and minor >= 8)) then
		error("Python version must be 3.8 or higher. Detected: " .. version)
	end

	print("SQUEEL: Python version valid!")

	return true
end

local create_venv = function(python, venv_path)
	print("SQUEEL: Creating venv for plugin squeel: " .. venv_path)
	local create_venv_cmd = string.format("%s -m venv %s", python, venv_path)

	local result = vim.fn.system(create_venv_cmd)
	if vim.v.shell_error ~= 0 then
		error("SQUEEL: Failed to create virtual environment: " .. result)
	end
end

local function install_requirements(python_executable, requirements_file)
	local install_cmd = string.format("%s -m pip install -r %s", python_executable, requirements_file)
	print("SQUEEL: Installing dependencies for plugin squeel: " .. install_cmd)
	local result = vim.fn.system(install_cmd)

	if vim.v.shell_error ~= 0 then
		error("SQUEEL: Failed to install requirements: " .. result)
	end
end

local function get_plugin_path()
	local plugin_name = "squeel.nvim"
	local plugin_path = nil
	for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
		if path:match(plugin_name) then
			plugin_path = path
			break
		end
	end
	if not plugin_path then
		error("SQUEEL: Plugin '" .. plugin_name .. "' not found in runtime paths.")
	end

	return plugin_path
end

local Path = require("plenary.path")
local data_path = vim.fn.stdpath("data")
local squeel_data = Path:new(data_path, "squeel")
local squeel_data_path = squeel_data:absolute()
local venv_path = squeel_data:joinpath(".venv"):absolute()
local python_path = venv_executable_path(venv_path)

local plugin_path = get_plugin_path()
local requirements_path = Path:new(plugin_path, "python", "requirements.txt"):absolute()
local python_file = Path:new(plugin_path, "python", "format_sql.py"):absolute()

local function format_sql_string(unformatted_text)
	local obj = vim.system({ python_path, python_file }, { stdin = unformatted_text }):wait()
	-- { code = 0, signal = 0, stdout = 'hello', stderr = '' }
	if not obj.code == 0 then
		error("SQUEEL: Formatting failed: " .. obj.stderr)
	end

	return vim.split(obj.stdout, "\n", { trimempty = true })
end

M.setup = function()
	if is_executable(python_path) then
		return
	end

	local python = find_python()
	validate_python(python)

	if vim.fn.isdirectory(squeel_data_path) == 0 then
		vim.fn.mkdir(squeel_data, "p")
	end

	create_venv(python, venv_path)

	if not file_exists(requirements_path) then
		error("SQUEEL: Can't find requirements.txt file")
	end

	local python_executable = venv_executable_path(venv_path)

	install_requirements(python_executable, requirements_path)

	print("SQUEEL: setup successful")
end

local embedded_sql = vim.treesitter.query.parse(
	"python",
	[[
		(
		  string
			 (string_start) @_s_start (#match? @_s_start "\"\"\"")
			 (string_content) @python_sql_string
				(#lua-match? @python_sql_string "^[%s\n]*%-%-%s*[Ss][Qq][Ll]")
			 (string_end) @_s_end (#match? @_s_end "\"\"\"")
		)
	]]
)

local get_root = function(bufnr)
	local parser = vim.treesitter.get_parser(bufnr, "python", {})
	local tree = parser:parse()[1]
	return tree:root()
end

local function get_leading_whitespace_in_buffer(bufnr, row)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

	if not line then
		error("Invalid buffer number or line number")
	end

	local leading_whitespace = line:match("^%s*")
	return #leading_whitespace
end

M.format = function(bufnr)
	local bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- if vim.bo[bufnr].filetype ~= "python" then
	-- 	vim.notify("SQUEEL: Can only be used with python filetype")
	-- 	return
	-- end

	local root = get_root(bufnr)

	local changes = {}
	for id, node in embedded_sql:iter_captures(root, bufnr, 0, -1) do
		local name = embedded_sql.captures[id]
		if name == "python_sql_string" then
			local start_row, start_col, end_row, end_col = node:range()

			local indent = get_leading_whitespace_in_buffer(bufnr, start_row)
			local indentation = string.rep(" ", indent + 4)

			local text = vim.treesitter.get_node_text(node, bufnr)
			-- Remove first line (contains only the -- sql comment)
			text = text:match("^[^\n]*\n?(.*)$")

			local formatted = format_sql_string(text)

			table.insert(changes, 1, {
				start = start_row + 1,
				final = end_row,
				formatted = formatted,
			})

			for idx, line in ipairs(formatted) do
				formatted[idx] = indentation .. line
			end
		end
	end

	for _, change in ipairs(changes) do
		vim.api.nvim_buf_set_lines(bufnr, change.start, change.final, false, change.formatted)
	end
end

return M
