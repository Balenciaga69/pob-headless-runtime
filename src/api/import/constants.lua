-- Shared importer states and wait policy.
local M = {}

M.states = {
    importing = "IMPORTING",
    get_account_name = "GETACCOUNTNAME",
    select_character = "SELECTCHAR",
}

M.wait_for_idle = {
    maxFrames = 200,
    maxSeconds = 15,
}

M.import_modes = {
    offline_payload = "offline_payload",
    remote_import = "remote_import",
}

return M
