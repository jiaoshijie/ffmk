local highlights = {
  FFMKNormal        = { default = true, link = "Normal" },
  FFMKTitleFlags    = { default = true, link = "Title" },
  FFMKPreviewCursor = { default = true, link = "Cursor" },
  FFMKBorder        = { default = true, link = "FloatBorder" },
  FFMKPreviewBorder = { default = true, link = "FloatBorder" },
  FFMKWarnMsg       = { default = true, link = "WarningMsg" },
}

for k, v in pairs(highlights) do
  vim.api.nvim_set_hl(0, k, v)
end
