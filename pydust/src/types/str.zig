// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;

const ffi = py.ffi;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;

pub const PyString = extern struct {
    obj: PyObject,

    pub usingnamespace PyObjectMixin("str", "PyUnicode", @This());

    pub fn create(value: []const u8) !PyString {
        const unicode = ffi.PyUnicode_FromStringAndSize(value.ptr, @intCast(value.len)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = unicode } };
    }

    /// Append other to self.
    ///
    /// Warning: a reference to self is stolen. Use concat, or self.incref(), if you don't own a reference to self.
    pub fn append(self: PyString, other: PyString) !PyString {
        return self.appendObj(other.obj);
    }

    /// Append the slice to self.
    ///
    /// Warning: a reference to self is stolen. Use concat, or self.incref(), if you don't own a reference to self.
    pub fn appendSlice(self: PyString, str: []const u8) !PyString {
        const other = try create(str);
        defer other.decref();
        return self.appendObj(other.obj);
    }

    fn appendObj(self: PyString, other: PyObject) !PyString {
        // This function effectively decref's the left-hand side.
        // The semantics therefore sort of imply mutation, and so we expose the same in our API.
        // FIXME(ngates): this comment
        var self_ptr: ?*ffi.PyObject = self.obj.py;
        ffi.PyUnicode_Append(&self_ptr, other.py);
        if (self_ptr) |ptr| {
            return PyString.unchecked(.{ .py = ptr });
        } else {
            // If set to null, then it failed.
            return PyError.Propagate;
        }
    }

    /// Concat other to self. Returns a new reference.
    pub fn concat(self: PyString, other: PyString) !PyString {
        const result = ffi.PyUnicode_Concat(self.obj.py, other.obj.py) orelse return PyError.Propagate;
        return PyString.unchecked(.{ .py = result });
    }

    /// Concat other to self. Returns a new reference.
    pub fn concatSlice(self: PyString, other: []const u8) !PyString {
        const otherString = try create(other);
        defer otherString.decref();

        return concat(self, otherString);
    }

    /// Return the length of the Unicode object, in code points.
    pub fn length(self: PyString) !usize {
        return @intCast(ffi.PyUnicode_GetLength(self.obj.py));
    }

    /// Returns a view over the PyString bytes.
    pub fn asSlice(self: PyString) ![:0]const u8 {
        var size: i64 = 0;
        const buffer: [*:0]const u8 = ffi.PyUnicode_AsUTF8AndSize(self.obj.py, &size) orelse return PyError.Propagate;
        return buffer[0..@as(usize, @intCast(size)) :0];
    }
};

const testing = std.testing;

test "PyString" {
    py.initialize();
    defer py.finalize();

    const a = "Hello";
    const b = ", world!";

    var ps = try PyString.create(a);
    // defer ps.decref();  <-- We don't need to decref here since append steals the reference to self.
    ps = try ps.appendSlice(b);
    defer ps.decref();

    var ps_slice = try ps.asSlice();

    // Null-terminated strings have len == non-null bytes, but are guaranteed to have a null byte
    // when indexed by their length.
    try testing.expectEqual(a.len + b.len, ps_slice.len);
    try testing.expectEqual(@as(u8, 0), ps_slice[ps_slice.len]);

    try testing.expectEqualStrings("Hello, world!", ps_slice);
}
