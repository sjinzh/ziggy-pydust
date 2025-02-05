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
const ffi = py.ffi;
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const PyError = @import("../errors.zig").PyError;

pub const PyBytes = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("bytes", "PyBytes", @This());

    pub fn create(value: []const u8) !PyBytes {
        const bytes = ffi.PyBytes_FromStringAndSize(value.ptr, @intCast(value.len)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = bytes } };
    }

    /// Return the bytes representation of object obj that implements the buffer protocol.
    pub fn fromObject(obj: anytype) !PyBytes {
        const pyobj = py.object(obj);
        const bytes = ffi.PyBytes_FromObject(pyobj.py) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = bytes } };
    }

    /// Return the length of the bytes object.
    pub fn length(self: PyBytes) !usize {
        return @intCast(ffi.PyBytes_Size(self.obj.py));
    }

    /// Returns a view over the PyBytes bytes.
    pub fn asSlice(self: PyBytes) ![:0]const u8 {
        var buffer: [*]u8 = undefined;
        var size: i64 = 0;
        if (ffi.PyBytes_AsStringAndSize(self.obj.py, @ptrCast(&buffer), &size) < 0) {
            return PyError.Propagate;
        }
        return buffer[0..@as(usize, @intCast(size)) :0];
    }
};

const testing = std.testing;

test "PyBytes" {
    py.initialize();
    defer py.finalize();

    const a = "Hello";

    var ps = try PyBytes.create(a);
    defer ps.decref();

    var ps_slice = try ps.asSlice();
    try testing.expectEqual(a.len, ps_slice.len);
    try testing.expectEqual(a.len, try ps.length());
    try testing.expectEqual(@as(u8, 0), ps_slice[ps_slice.len]);

    try testing.expectEqualStrings("Hello", ps_slice);
}
