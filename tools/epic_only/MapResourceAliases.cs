using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

// Resource block layouts cross-checked with ValveResourceFormat's
// ResourceExtRefList and ResourceManifest readers, and Valve resourceinfo.exe.
public static class MapResourceAliases
{
    private sealed class Block { public string Kind; public byte[] Data; }
    private sealed class Reference { public ulong Id; public string Name; }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidDataException(message);
    }

    private static string ReadString(byte[] bytes, int offset)
    {
        int end = offset;
        while (end < bytes.Length && bytes[end] != 0) end++;
        Require(end < bytes.Length, "Unterminated resource string.");
        return Encoding.UTF8.GetString(bytes, offset, end - offset);
    }

    private static string Alias(string name, string source, string target)
    {
        string root = "maps/" + source;
        return name.StartsWith(root + "/", StringComparison.Ordinal)
            ? "maps/" + target + name.Substring(root.Length) : null;
    }

    public static ulong ResourceId(string name)
    {
        // MurmurHash64B, the Source 2 resource ID seed. Inputs here are lowercase
        // resource names using '/' and do not include the compiled '_c' suffix.
        byte[] data = Encoding.UTF8.GetBytes(name.ToLowerInvariant());
        const uint multiplier = 0x5bd1e995;
        uint first = 0xedabcdef ^ (uint)data.Length;
        uint second = 0;
        int index = 0;
        while (index + 8 <= data.Length)
        {
            uint part = BitConverter.ToUInt32(data, index);
            part *= multiplier;
            part ^= part >> 24;
            part *= multiplier;
            first = (first * multiplier) ^ part;
            part = BitConverter.ToUInt32(data, index + 4);
            part *= multiplier;
            part ^= part >> 24;
            part *= multiplier;
            second = (second * multiplier) ^ part;
            index += 8;
        }
        if (index + 4 <= data.Length)
        {
            uint part = BitConverter.ToUInt32(data, index);
            part *= multiplier;
            part ^= part >> 24;
            part *= multiplier;
            first = (first * multiplier) ^ part;
            index += 4;
        }
        if (index < data.Length)
        {
            uint tail = 0;
            for (int shift = 0; index < data.Length; shift += 8, index++) tail |= (uint)data[index] << shift;
            second ^= tail;
            second *= multiplier;
        }
        first ^= second >> 18;
        first *= multiplier;
        second ^= first >> 22;
        second *= multiplier;
        first ^= second >> 17;
        first *= multiplier;
        second ^= first >> 19;
        second *= multiplier;
        return ((ulong)first << 32) | second;
    }

    private static byte[] ExpandReferences(byte[] data, string source, string target)
    {
        int start = BitConverter.ToInt32(data, 0);
        int count = BitConverter.ToInt32(data, 4);
        var references = new List<Reference>();
        for (int i = 0; i < count; i++)
        {
            int position = start + i * 16;
            ulong id = BitConverter.ToUInt64(data, position);
            string name = ReadString(data, position + 8 + BitConverter.ToInt32(data, position + 8));
            Require(ResourceId(name) == id, "Resource ID hash mismatch: " + name);
            references.Add(new Reference { Id = id, Name = name });
            string alias = Alias(name, source, target);
            if (alias != null) references.Add(new Reference { Id = ResourceId(alias), Name = alias });
        }
        references = references.OrderBy(reference => reference.Name, StringComparer.Ordinal).ToList();
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write(12);
            writer.Write(references.Count);
            writer.Write(0);
            int stringsPosition = 12 + references.Count * 16;
            for (int i = 0; i < references.Count; i++)
            {
                writer.Write(references[i].Id);
                writer.Write(stringsPosition - (12 + i * 16 + 8));
                writer.Write(0);
                stringsPosition += Encoding.UTF8.GetByteCount(references[i].Name) + 1;
            }
            foreach (Reference reference in references)
            {
                writer.Write(Encoding.UTF8.GetBytes(reference.Name));
                writer.Write((byte)0);
            }
            return stream.ToArray();
        }
    }

    private static byte[] ExpandManifest(byte[] data, string source, string target)
    {
        Require(BitConverter.ToInt32(data, 0) == 8 && BitConverter.ToInt32(data, 4) == 1,
            "Expected the original map's single-group resource manifest.");
        int start = 8 + BitConverter.ToInt32(data, 8);
        int count = BitConverter.ToInt32(data, 12);
        var names = new List<string>();
        for (int i = 0; i < count; i++)
        {
            int position = start + i * 4;
            string name = ReadString(data, position + BitConverter.ToInt32(data, position));
            names.Add(name);
            string alias = Alias(name, source, target);
            if (alias != null) names.Add(alias);
        }
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write(8);
            writer.Write(1);
            writer.Write(8);
            writer.Write(names.Count);
            int stringsPosition = 16 + names.Count * 4;
            for (int i = 0; i < names.Count; i++)
            {
                writer.Write(stringsPosition - (16 + i * 4));
                stringsPosition += Encoding.UTF8.GetByteCount(names[i]) + 1;
            }
            foreach (string name in names)
            {
                writer.Write(Encoding.UTF8.GetBytes(name));
                writer.Write((byte)0);
            }
            return stream.ToArray();
        }
    }

    public static byte[] Repair(byte[] resource, bool manifest, string source, string target)
    {
        Require(BitConverter.ToUInt16(resource, 4) == 12, "Unexpected resource header version.");
        Require(BitConverter.ToUInt32(resource, 0) == resource.Length, "Unexpected streaming resource data.");
        int table = 8 + BitConverter.ToInt32(resource, 8);
        int count = BitConverter.ToInt32(resource, 12);
        Require(table == 16 && count == 3, "Unexpected map/manifest resource block layout.");
        var blocks = new List<Block>();
        for (int i = 0; i < count; i++)
        {
            int position = table + i * 12;
            string kind = Encoding.ASCII.GetString(resource, position, 4);
            int start = position + 4 + BitConverter.ToInt32(resource, position + 4);
            int length = BitConverter.ToInt32(resource, position + 8);
            var bytes = new byte[length];
            Array.Copy(resource, start, bytes, 0, length);
            if (kind == "RERL") bytes = ExpandReferences(bytes, source, target);
            else if (kind == "DATA" && manifest) bytes = ExpandManifest(bytes, source, target);
            else Require(kind == "RED2" || kind == "DATA", "Unexpected resource block " + kind);
            blocks.Add(new Block { Kind = kind, Data = bytes });
        }
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write(resource, 0, table + count * 12);
            for (int i = 0; i < count; i++)
            {
                while (stream.Position % 16 != 0) writer.Write((byte)0);
                int start = checked((int)stream.Position);
                writer.Write(blocks[i].Data);
                long end = stream.Position;
                stream.Position = table + i * 12 + 4;
                writer.Write(start - checked((int)stream.Position));
                writer.Write(blocks[i].Data.Length);
                stream.Position = end;
            }
            int length = checked((int)stream.Length);
            stream.Position = 0;
            writer.Write(length);
            return stream.ToArray();
        }
    }
}
