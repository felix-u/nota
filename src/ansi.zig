const builtin = @import("builtin");
const std = @import("std");

const Writer = std.fs.File.Writer;

pub const beg = "\x1b[";
pub const end = "m";

pub const fg_black = "30";
pub const fg_red = "31";
pub const fg_green = "32";
pub const fg_yellow = "33";
pub const fg_blue = "34";
pub const fg_magenta = "35";
pub const fg_cyan = "36";
pub const fg_grey = "37";
pub const fg_black_bright = "90";
pub const fg_red_bright = "91";
pub const fg_yellow_bright = "92";
pub const fg_green_bright = "93";
pub const fg_blue_bright = "94";
pub const fg_magenta_bright = "95";
pub const fg_cyan_bright = "96";
pub const fg_grey_bright = "97";

pub const bg_black = "40";
pub const bg_red = "41";
pub const bg_green = "42";
pub const bg_yellow = "43";
pub const bg_blue = "44";
pub const bg_magenta = "45";
pub const bg_cyan = "46";
pub const bg_grey = "47";
pub const bg_black_bright = "100";
pub const bg_red_bright = "101";
pub const bg_yellow_bright = "102";
pub const bg_green_bright = "103";
pub const bg_blue_bright = "104";
pub const bg_magenta_bright = "105";
pub const bg_cyan_bright = "106";
pub const bg_grey_bright = "107";

pub const fmt_reset = "0";
pub const fmt_bold = "1";
pub const fmt_italic = "3";
pub const fmt_underline = "4";
pub const fmt_normal = "22";

pub fn set(writer: Writer, comptime fmts: []const []const u8) !void {
    _ = try writer.write(beg);
    inline for (fmts[0..fmts.len]) |fmt| _ = try writer.write(fmt ++ ";");
    _ = try writer.write(fmts[fmts.len - 1] ++ end);
}

pub inline fn reset(writer: std.fs.File.Writer) !void {
    try set(writer, &.{fmt_reset});
}
