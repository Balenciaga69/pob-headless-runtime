local M = {}

function M.new()
    return {
        lines = {},
        separators = 0,
        Clear = function(self)
            self.lines = {}
            self.separators = 0
        end,
        AddLine = function(self, _, text)
            self.lines[#self.lines + 1] = {
                kind = "line",
                text = text,
                plainText = _G.StripEscapes and _G.StripEscapes(text or "") or (text or ""),
            }
        end,
        AddSeparator = function(self)
            self.separators = self.separators + 1
            self.lines[#self.lines + 1] = {
                kind = "separator",
                text = "--------",
                plainText = "--------",
            }
        end,
    }
end

return M
