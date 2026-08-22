param(
    [string]$Match = "Wireless Microphone RX"
)

$ErrorActionPreference = "Stop"

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$code = @"
using System;
using System.Runtime.InteropServices;

namespace MicAudio
{
    public enum EDataFlow
    {
        eRender = 0,
        eCapture = 1,
        eAll = 2
    }

    public enum ERole
    {
        eConsole = 0,
        eMultimedia = 1,
        eCommunications = 2
    }

    [Flags]
    public enum DeviceState : uint
    {
        Active = 0x00000001,
        Disabled = 0x00000002,
        NotPresent = 0x00000004,
        Unplugged = 0x00000008,
        All = 0x0000000F
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropertyKey
    {
        public Guid fmtid;
        public uint pid;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PropVariant
    {
        [FieldOffset(0)]
        public ushort vt;

        [FieldOffset(8)]
        public IntPtr pointerValue;

        public string GetString()
        {
            return Marshal.PtrToStringUni(pointerValue);
        }
    }

    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorComObject
    {
    }

    [ComImport]
    [Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
    public class PolicyConfigClient
    {
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    public interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(EDataFlow dataFlow, DeviceState stateMask, [MarshalAs(UnmanagedType.Interface)] out IMMDeviceCollection devices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, [MarshalAs(UnmanagedType.Interface)] out IMMDevice endpoint);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, [MarshalAs(UnmanagedType.Interface)] out IMMDevice device);
        int RegisterEndpointNotificationCallback(IntPtr client);
        int UnregisterEndpointNotificationCallback(IntPtr client);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("0BD7A1BE-7A1A-44DB-8397-C0C356C8D1BD")]
    public interface IMMDeviceCollection
    {
        int GetCount(out uint count);
        int Item(uint index, [MarshalAs(UnmanagedType.Interface)] out IMMDevice device);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    public interface IMMDevice
    {
        int Activate(ref Guid iid, uint clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
        int OpenPropertyStore(uint storageAccess, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore properties);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetState(out DeviceState state);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    public interface IPropertyStore
    {
        int GetCount(out uint propertyCount);
        int GetAt(uint propertyIndex, out PropertyKey key);
        int GetValue(ref PropertyKey key, out PropVariant value);
        int SetValue(ref PropertyKey key, ref PropVariant value);
        int Commit();
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("F8679F50-850A-41CF-9C72-430F290290C8")]
    public interface IPolicyConfig
    {
        int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceName, out IntPtr format);
        int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceName, int defaultFormat, out IntPtr format);
        int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceName);
        int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceName, IntPtr endpointFormat, IntPtr mixFormat);
        int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string deviceName, int defaultPeriod, out long defaultDevicePeriod, out long minimumDevicePeriod);
        int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string deviceName, ref long period);
        int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string deviceName, IntPtr mode);
        int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string deviceName, IntPtr mode);
        int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string deviceName, ref PropertyKey key, out PropVariant value);
        int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string deviceName, ref PropertyKey key, ref PropVariant value);
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceName, ERole role);
        int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string deviceName, int visible);
    }

    public class AudioEndpointInfo
    {
        public string Name { get; set; }
        public string Id { get; set; }
    }

    public static class AudioTools
    {
        private static readonly PropertyKey FriendlyNameKey = new PropertyKey
        {
            fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"),
            pid = 14
        };

        private static IMMDeviceEnumerator CreateEnumerator()
        {
            return (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
        }

        private static string GetId(IMMDevice device)
        {
            string id;
            Marshal.ThrowExceptionForHR(device.GetId(out id));
            return id;
        }

        private static string GetName(IMMDevice device)
        {
            IPropertyStore properties;
            Marshal.ThrowExceptionForHR(device.OpenPropertyStore(0, out properties));
            PropertyKey key = FriendlyNameKey;
            PropVariant value;
            Marshal.ThrowExceptionForHR(properties.GetValue(ref key, out value));
            return value.GetString();
        }

        private static AudioEndpointInfo ToInfo(IMMDevice device)
        {
            return new AudioEndpointInfo
            {
                Name = GetName(device),
                Id = GetId(device)
            };
        }

        public static AudioEndpointInfo[] GetEndpoints(EDataFlow flow)
        {
            IMMDeviceEnumerator enumerator = CreateEnumerator();
            IMMDeviceCollection collection;
            Marshal.ThrowExceptionForHR(enumerator.EnumAudioEndpoints(flow, DeviceState.Active, out collection));
            uint count;
            Marshal.ThrowExceptionForHR(collection.GetCount(out count));

            AudioEndpointInfo[] endpoints = new AudioEndpointInfo[count];
            for (uint i = 0; i < count; i++)
            {
                IMMDevice device;
                Marshal.ThrowExceptionForHR(collection.Item(i, out device));
                endpoints[i] = ToInfo(device);
            }

            return endpoints;
        }

        public static AudioEndpointInfo GetDefault(EDataFlow flow)
        {
            IMMDeviceEnumerator enumerator = CreateEnumerator();
            IMMDevice device;
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(flow, ERole.eMultimedia, out device));
            return ToInfo(device);
        }

        public static void SetDefaultEndpoint(string id, ERole role)
        {
            IPolicyConfig policyConfig = (IPolicyConfig)(new PolicyConfigClient());
            int result = policyConfig.SetDefaultEndpoint(id, role);
            if (result != 0)
            {
                Marshal.ThrowExceptionForHR(result);
            }
        }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'MicAudio.AudioTools').Type) {
    Add-Type -TypeDefinition $code
}

$currentOutput = [MicAudio.AudioTools]::GetDefault([MicAudio.EDataFlow]::eRender)
$currentInput = [MicAudio.AudioTools]::GetDefault([MicAudio.EDataFlow]::eCapture)
$captureDevices = [MicAudio.AudioTools]::GetEndpoints([MicAudio.EDataFlow]::eCapture)

Write-Host "Current playback/output stays unchanged:"
Write-Host "  $($currentOutput.Name)"
Write-Host ""
Write-Host "Current recording/input:"
Write-Host "  $($currentInput.Name)"
Write-Host ""
Write-Host "Available recording/input devices:"
$captureDevices | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""

$target = $captureDevices | Where-Object { $_.Name -like "*$Match*" } | Select-Object -First 1
if (-not $target) {
    throw "Could not find a recording device matching '$Match'."
}

foreach ($role in @([MicAudio.ERole]::eConsole, [MicAudio.ERole]::eMultimedia, [MicAudio.ERole]::eCommunications)) {
    [MicAudio.AudioTools]::SetDefaultEndpoint($target.Id, $role)
}

$newInput = [MicAudio.AudioTools]::GetDefault([MicAudio.EDataFlow]::eCapture)
Write-Host "Done. New recording/input default:"
Write-Host "  $($newInput.Name)"
Write-Host ""
Write-Host "Playback/output was not changed:"
Write-Host "  $($currentOutput.Name)"
