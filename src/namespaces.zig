//! WHATWG Infra Namespace Constants
//!
//! Spec: https://infra.spec.whatwg.org/#namespaces
//!
//! Namespace constants used by various web specifications (HTML, SVG, MathML, etc.)

const std = @import("std");

pub const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
pub const MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML";
pub const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
pub const XLINK_NAMESPACE = "http://www.w3.org/1999/xlink";
pub const XML_NAMESPACE = "http://www.w3.org/XML/1998/namespace";
pub const XMLNS_NAMESPACE = "http://www.w3.org/2000/xmlns/";

test "HTML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xhtml", HTML_NAMESPACE);
}

test "MathML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1998/Math/MathML", MATHML_NAMESPACE);
}

test "SVG namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/2000/svg", SVG_NAMESPACE);
}

test "XLink namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xlink", XLINK_NAMESPACE);
}

test "XML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/XML/1998/namespace", XML_NAMESPACE);
}

test "XMLNS namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", XMLNS_NAMESPACE);
}
