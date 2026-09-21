using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

// This is a narrow VPK v2 copier for the unsigned, single-file Necropolis package.
// Original resources remain intact. New-name map/manifest metadata registers both
// namespaces; geometry and entity data continue to use their original references.
public static class EpicOnlyMapPackage
{
    private const uint Magic = 0x55aa1234;
    private const ushort InlineArchive = 0x7fff;
    private static readonly uint[] CrcTable = MakeCrcTable();

    private sealed class Entry
    {
        public string Extension, Directory, Name;
        public uint Crc, Offset, Length;
        public byte[] Preload;
        public string Path { get { return Directory + "/" + Name + "." + Extension; } }
    }

    private sealed class Package
    {
        public byte[] Bytes;
        public int TreeLength, DataLength, ArchiveHashLength, SignatureLength;
        public int DataStart { get { return 28 + TreeLength; } }
        public int HashStart { get { return DataStart + DataLength; } }
        public int OtherHashStart { get { return HashStart + ArchiveHashLength; } }
        public List<Entry> Entries = new List<Entry>();
    }

    private static void Require(bool valid, string message)
    {
        if (!valid) throw new InvalidDataException(message);
    }

    private static byte[] Md5(byte[] bytes, int start, int length)
    {
        using (var md5 = MD5.Create()) return md5.ComputeHash(bytes, start, length);
    }

    private static bool Equal(byte[] first, int offset, byte[] second, int otherOffset, int length)
    {
        for (int i = 0; i < length; i++)
            if (first[offset + i] != second[otherOffset + i]) return false;
        return true;
    }

    private static string ReadString(BinaryReader reader, long limit)
    {
        var bytes = new List<byte>();
        while (reader.BaseStream.Position < limit)
        {
            byte value = reader.ReadByte();
            if (value == 0) return Encoding.UTF8.GetString(bytes.ToArray());
            bytes.Add(value);
        }
        throw new InvalidDataException("Unterminated VPK directory string.");
    }

    private static void WriteString(BinaryWriter writer, string value)
    {
        writer.Write(Encoding.UTF8.GetBytes(value));
        writer.Write((byte)0);
    }

    private static Package Read(string path)
    {
        var package = new Package { Bytes = File.ReadAllBytes(path) };
        using (var reader = new BinaryReader(new MemoryStream(package.Bytes)))
        {
            Require(reader.ReadUInt32() == Magic, "Not a VPK: " + path);
            Require(reader.ReadUInt32() == 2, "Only VPK v2 is supported.");
            package.TreeLength = checked((int)reader.ReadUInt32());
            package.DataLength = checked((int)reader.ReadUInt32());
            package.ArchiveHashLength = checked((int)reader.ReadUInt32());
            Require(reader.ReadUInt32() == 48, "Expected the three VPK MD5 hashes.");
            package.SignatureLength = checked((int)reader.ReadUInt32());
            Require(package.SignatureLength == 20, "Expected the unsigned Source 2 signature descriptor.");
            Require((long)package.OtherHashStart + 48 + 20 == package.Bytes.Length,
                "Unexpected VPK sections or trailing bytes.");
            int signatureStart = package.OtherHashStart + 48;
            Require(BitConverter.ToUInt32(package.Bytes, signatureStart) == Magic
                && BitConverter.ToUInt32(package.Bytes, signatureStart + 4) == 1
                && BitConverter.ToUInt32(package.Bytes, signatureStart + 8) == 0
                && BitConverter.ToUInt32(package.Bytes, signatureStart + 12) == 0
                && BitConverter.ToUInt32(package.Bytes, signatureStart + 16) == 0,
                "Refusing to alter a signed or unsupported package.");

            string extension, directory, name;
            var paths = new HashSet<string>(StringComparer.Ordinal);
            while ((extension = ReadString(reader, package.DataStart)) != "")
            {
                while ((directory = ReadString(reader, package.DataStart)) != "")
                {
                    while ((name = ReadString(reader, package.DataStart)) != "")
                    {
                        var entry = new Entry { Extension = extension, Directory = directory, Name = name };
                        entry.Crc = reader.ReadUInt32();
                        ushort preloadLength = reader.ReadUInt16();
                        Require(reader.ReadUInt16() == InlineArchive, "External VPK chunks are unsupported.");
                        entry.Offset = reader.ReadUInt32();
                        entry.Length = reader.ReadUInt32();
                        Require(reader.ReadUInt16() == 0xffff, "Invalid VPK entry terminator.");
                        entry.Preload = reader.ReadBytes(preloadLength);
                        Require(entry.Preload.Length == preloadLength && reader.BaseStream.Position <= package.DataStart,
                            "Invalid VPK preload data.");
                        Require((long)entry.Offset + entry.Length <= package.DataLength, "VPK entry exceeds data section.");
                        Require(paths.Add(entry.Path), "Duplicate VPK entry: " + entry.Path);
                        package.Entries.Add(entry);
                    }
                }
            }
            Require(reader.BaseStream.Position == package.DataStart, "Directory size mismatch.");
        }
        VerifyHashes(package);
        return package;
    }

    private static void VerifyHashes(Package package)
    {
        Require(Equal(Md5(package.Bytes, 28, package.TreeLength), 0, package.Bytes, package.OtherHashStart, 16),
            "VPK directory MD5 mismatch.");
        Require(Equal(Md5(package.Bytes, package.HashStart, package.ArchiveHashLength), 0,
            package.Bytes, package.OtherHashStart + 16, 16), "VPK archive table MD5 mismatch.");
        Require(Equal(Md5(package.Bytes, 0, package.OtherHashStart + 32), 0,
            package.Bytes, package.OtherHashStart + 32, 16), "VPK whole-file MD5 mismatch.");
        Require(package.ArchiveHashLength % 28 == 0, "Invalid VPK archive hash table.");
        for (int pos = package.HashStart; pos < package.OtherHashStart; pos += 28)
        {
            uint archive = BitConverter.ToUInt32(package.Bytes, pos);
            // Workshop packages use 0x80000000 for MD5 of their own data section.
            Require(archive == InlineArchive || archive == 0x80000000, "Unsupported archive hash type.");
            int offset = checked((int)BitConverter.ToUInt32(package.Bytes, pos + 4));
            int length = checked((int)BitConverter.ToUInt32(package.Bytes, pos + 8));
            Require((long)offset + length <= package.DataLength, "Archive hash exceeds data section.");
            Require(Equal(Md5(package.Bytes, package.DataStart + offset, length), 0, package.Bytes, pos + 12, 16),
                "VPK data chunk MD5 mismatch.");
        }
        foreach (Entry entry in package.Entries)
        {
            uint crc = 0xffffffff;
            foreach (byte value in entry.Preload) crc = CrcTable[(crc ^ value) & 255] ^ (crc >> 8);
            int start = checked(package.DataStart + (int)entry.Offset);
            int end = checked(start + (int)entry.Length);
            for (int i = start; i < end; i++) crc = CrcTable[(crc ^ package.Bytes[i]) & 255] ^ (crc >> 8);
            Require((crc ^ 0xffffffff) == entry.Crc, "VPK file CRC mismatch: " + entry.Path);
        }
    }

    private static uint[] MakeCrcTable()
    {
        var table = new uint[256];
        for (uint i = 0; i < table.Length; i++)
        {
            uint value = i;
            for (int bit = 0; bit < 8; bit++) value = (value & 1) == 0 ? value >> 1 : (value >> 1) ^ 0xedb88320;
            table[i] = value;
        }
        return table;
    }

    private static Entry Alias(Entry entry, string sourceMap, string targetMap)
    {
        string root = "maps/" + sourceMap;
        Require(entry.Path.StartsWith(root + "/", StringComparison.Ordinal)
            || entry.Path.StartsWith(root + ".", StringComparison.Ordinal),
            "Unexpected source package namespace: " + entry.Path);
        return new Entry {
            Extension = entry.Extension,
            Directory = entry.Directory == "maps" ? "maps" : "maps/" + targetMap + entry.Directory.Substring(root.Length),
            Name = entry.Directory == "maps" ? targetMap : entry.Name,
            Crc = entry.Crc, Offset = entry.Offset, Length = entry.Length, Preload = entry.Preload
        };
    }

    private static bool NeedsMetadataRepair(Entry entry)
    {
        return entry.Extension == "vmap_c" || entry.Extension == "vrman_c";
    }

    private static byte[] Payload(Package package, Entry entry)
    {
        var bytes = new byte[checked(entry.Preload.Length + (int)entry.Length)];
        Array.Copy(entry.Preload, bytes, entry.Preload.Length);
        Array.Copy(package.Bytes, package.DataStart + entry.Offset, bytes, entry.Preload.Length, entry.Length);
        return bytes;
    }

    private static byte[] RepairedPayload(Package package, Entry entry, string sourceMap, string targetMap)
    {
        return MapResourceAliases.Repair(Payload(package, entry), entry.Extension == "vrman_c", sourceMap, targetMap);
    }

    private static uint Crc32(byte[] bytes)
    {
        uint crc = 0xffffffff;
        foreach (byte value in bytes) crc = CrcTable[(crc ^ value) & 255] ^ (crc >> 8);
        return crc ^ 0xffffffff;
    }

    private static byte[] ChunkHashes(byte[] data)
    {
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            for (int offset = 0; offset < data.Length; offset += 1024 * 1024)
            {
                int length = Math.Min(1024 * 1024, data.Length - offset);
                writer.Write((uint)0x80000000);
                writer.Write((uint)offset);
                writer.Write((uint)length);
                writer.Write(Md5(data, offset, length));
            }
            return stream.ToArray();
        }
    }

    public static void Build(string source, string destination, string sourceMap, string targetMap)
    {
        Require(!String.Equals(Path.GetFullPath(source), Path.GetFullPath(destination), StringComparison.OrdinalIgnoreCase),
            "Source and destination must differ.");
        var original = Read(source);
        var entries = new List<Entry>(original.Entries);
        byte[] data;
        using (var stream = new MemoryStream())
        {
            stream.Write(original.Bytes, original.DataStart, original.DataLength);
            foreach (Entry entry in original.Entries)
            {
                Entry alias = Alias(entry, sourceMap, targetMap);
                if (NeedsMetadataRepair(entry))
                {
                    byte[] repaired = RepairedPayload(original, entry, sourceMap, targetMap);
                    alias.Preload = new byte[0];
                    alias.Offset = checked((uint)stream.Position);
                    alias.Length = checked((uint)repaired.Length);
                    alias.Crc = Crc32(repaired);
                    stream.Write(repaired, 0, repaired.Length);
                }
                entries.Add(alias);
            }
            data = stream.ToArray();
        }
        byte[] hashes = ChunkHashes(data);
        byte[] tree;
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            foreach (var extension in entries.GroupBy(entry => entry.Extension).OrderBy(group => group.Key, StringComparer.Ordinal))
            {
                WriteString(writer, extension.Key);
                foreach (var directory in extension.GroupBy(entry => entry.Directory).OrderBy(group => group.Key, StringComparer.Ordinal))
                {
                    WriteString(writer, directory.Key);
                    foreach (var entry in directory.OrderBy(value => value.Name, StringComparer.Ordinal))
                    {
                        WriteString(writer, entry.Name);
                        writer.Write(entry.Crc);
                        writer.Write(checked((ushort)entry.Preload.Length));
                        writer.Write(InlineArchive);
                        writer.Write(entry.Offset);
                        writer.Write(entry.Length);
                        writer.Write((ushort)0xffff);
                        writer.Write(entry.Preload);
                    }
                    writer.Write((byte)0);
                }
                writer.Write((byte)0);
            }
            writer.Write((byte)0);
            tree = stream.ToArray();
        }
        byte[] result;
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write(Magic);
            writer.Write((uint)2);
            writer.Write((uint)tree.Length);
            writer.Write((uint)data.Length);
            writer.Write((uint)hashes.Length);
            writer.Write((uint)48);
            writer.Write((uint)20);
            writer.Write(tree);
            writer.Write(data);
            writer.Write(hashes);
            writer.Write(Md5(tree, 0, tree.Length));
            writer.Write(Md5(hashes, 0, hashes.Length));
            byte[] prefix = stream.ToArray();
            writer.Write(Md5(prefix, 0, prefix.Length));
            writer.Write(original.Bytes, original.OtherHashStart + 48, 20);
            result = stream.ToArray();
        }
        // Do not overwrite an unrelated or manually edited map package.
        if (File.Exists(destination) && !File.ReadAllBytes(destination).SequenceEqual(result))
            ValidateClone(original, Read(destination), sourceMap, targetMap, true);
        File.WriteAllBytes(destination, result);
        Require(File.ReadAllBytes(source).SequenceEqual(original.Bytes), "Source changed during build.");
        VerifyClone(source, destination, sourceMap, targetMap);
    }

    public static void VerifyClone(string source, string destination, string sourceMap, string targetMap)
    {
        var original = Read(source);
        var clone = Read(destination);
        ValidateClone(original, clone, sourceMap, targetMap, false);
        Console.WriteLine("Verified {0} original entries + {0} aliases; all CRC32 and VPK MD5 checks passed.", original.Entries.Count);
        Console.WriteLine("Original resource bytes are unchanged; {0} new-name map/manifest resources register both namespaces.",
            original.Entries.Count(NeedsMetadataRepair));
    }

    private static void ValidateClone(Package original, Package clone, string sourceMap, string targetMap, bool allowOldMetadata)
    {
        Require(original.DataLength <= clone.DataLength
            && Equal(original.Bytes, original.DataStart, clone.Bytes, clone.DataStart, original.DataLength),
            "Original compiled resource payloads changed.");
        Require(clone.Entries.Count == original.Entries.Count * 2, "Wrong alias count.");
        var cloneEntries = clone.Entries.ToDictionary(entry => entry.Path, StringComparer.Ordinal);
        foreach (Entry entry in original.Entries)
        {
            Entry other;
            Require(cloneEntries.TryGetValue(entry.Path, out other), "Missing original entry: " + entry.Path);
            Require(entry.Crc == other.Crc && entry.Offset == other.Offset && entry.Length == other.Length
                && entry.Preload.SequenceEqual(other.Preload), "Changed original entry: " + entry.Path);

            string name = Alias(entry, sourceMap, targetMap).Path;
            Require(cloneEntries.TryGetValue(name, out other), "Missing alias: " + name);
            byte[] expected = NeedsMetadataRepair(entry)
                ? RepairedPayload(original, entry, sourceMap, targetMap) : Payload(original, entry);
            byte[] actual = Payload(clone, other);
            if (!actual.SequenceEqual(expected))
            {
                Require(allowOldMetadata && NeedsMetadataRepair(entry) && actual.SequenceEqual(Payload(original, entry)),
                    "Unexpected alias contents: " + name);
            }
        }
    }
}
