data:extend({
	{
		type = 'selection-tool',
		name = 'combinator-select-tool',
		stack_size = 1,
		order = 'a',
		hidden = true,
		icon = '__controllinator__/graphics/item/combinator-select-tool.png',
		icon_size = 32,
		select = {
			border_color = { r = 0, g = 1, b = 0 },
			cursor_box_type = 'entity',
			mode = { 'buildable-type', 'same-force' },
		},
		alt_select = {
			border_color = { r = 1, g = 0, b = 0 },
			cursor_box_type = 'not-allowed',
			mode = { 'buildable-type', 'same-force' },
		},
		always_include_tiles = false,
	}
})
