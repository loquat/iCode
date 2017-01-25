VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CVBMemoryAllocator"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Attribute VB_Ext_KEY = "SavedWithClassBuilder6" ,"Yes"
Attribute VB_Ext_KEY = "Top_Level" ,"Yes"
'***********************************************************************************************************************
'
'ģ �� ��: CVBMemoryAllocator
'
'��    ��: Supergreenbean
'
'��������: ��ָ�������з����ڴ�
'
'��    ��: 2005��03��03��
'
'ʹ��˵��:
'       1.�����ڴ�
'           ��:
'               ����Ŀ�����IDΪ&HC80
'
'               ����Ŀ������з���һ����СΪ1024���ֽڵ��ڴ�飬���趨����CVBPEFnLocator������ʱ�Զ��ͷŸ��ڴ��
'                   Dim hMem As Long
'                   lIndex = oMemAllocator.Allocate(1024, hMem, &HC80)
'
'               ����Ŀ������з���һ����СΪ1024���ֽڵ��ڴ�飬���趨����CVBPEFnLocator������ʱ���Զ��ͷŸ��ڴ��
'                   lIndex = oMemAllocator.Allocate(1024, &HC80, False)
'       2.�ͷ��ڴ�
'           ��:
'               ���ͷ���������ָ���ڴ��
'                   fSuccess = oMemAllocator.Release(lIndex)
'***********************************************************************************************************************
'
Option Explicit
                                                                 
'��ģ������
Private Const THIS_MODULE_NAME        As String = "CVBMemoryAllocator"
'=======================================================================================================================
'����ΪWindows API�������
'=======================================================================================================================
Private Declare Function GetCurrentProcessId Lib "kernel32" () As Long
Private Declare Function OpenProcess Lib "kernel32" (ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, ByVal dwProcessId As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal hObject As Long) As Long
Private Const PROCESS_ALL_ACCESS = &H1F0FFF
Private Declare Function VirtualAllocEx Lib "kernel32" (ByVal hProcess As Long, lpAddress As Any, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As Long
Private Declare Function VirtualFreeEx Lib "kernel32" (ByVal hProcess As Long, lpAddress As Any, ByVal dwSize As Long, ByVal dwFreeType As Long) As Long
Private Const MEM_COMMIT = &H1000&
Private Const MEM_RESERVE = &H2000&
Private Const MEM_DECOMMIT = &H4000&
Private Const MEM_RELEASE = &H8000&
Private Const PAGE_READWRITE          As Long = &H4
Private Const PAGE_EXECUTE_READWRITE  As Long = &H40&
Private Declare Function CreateFileMapping Lib "kernel32" Alias "CreateFileMappingA" (ByVal hFile As Long, lpFileMappigAttributes As Any, ByVal flProtect As Long, ByVal dwMaximumSizeHigh As Long, ByVal dwMaximumSizeLow As Long, ByVal lpName As String) As Long
Private Declare Function MapViewOfFile Lib "kernel32" (ByVal hFileMappingObject As Long, ByVal dwDesiredAccess As Long, ByVal dwFileOffsetHigh As Long, ByVal dwFileOffsetLow As Long, ByVal dwNumberOfBytesToMap As Long) As Long
Private Declare Function UnmapViewOfFile Lib "kernel32" (lpBaseAddress As Any) As Long
Private Const FILE_MAP_ALL_ACCESS = &HF001F
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (Destination As Any, Source As Long, ByVal Length As Long)
Private Declare Function GetVersionEx Lib "kernel32" Alias "GetVersionExA" (lpVersionInformation As OSVERSIONINFO) As Long
Private Type OSVERSIONINFO
    dwOSVersionInfoSize               As Long
    dwMajorVersion                    As Long
    dwMinorVersion                    As Long
    dwBuildNumber                     As Long
    dwPlatformId                      As Long
    szCSDVersion                      As String * 128
End Type
Private Const VER_PLATFORM_WIN32s = 0&
Private Const VER_PLATFORM_WIN32_WINDOWS = 1&
Private Const VER_PLATFORM_WIN32_NT = 2&
Private Declare Function CoCreateGuid Lib "ole32.dll" (lpGUID As Any) As Long
Private Declare Function StringFromGUID2 Lib "ole32" (lpGUID As Any, ByVal lpStr As String, ByVal lSize As Long) As Long
'=======================================================================================================================
'����ΪWindows API�������
'=======================================================================================================================
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'=======================================================================================================================
'����Ϊ���ڲ�˽�б���
'=======================================================================================================================
'�ڴ�����¼
Private Type ALLOCATED_MEMORY_RECORD
    hFile                             As Long                                   '�ļ�ӳ����
    AllocatedAddress                  As Long                                   '��������ڴ��ַ
    AllocatedSize                     As Long                                   '��������ڴ��С
    TargetProcessID                   As Long                                   'Ŀ�����ID
    AutoReleaseOnExit                 As Boolean                                '�Ƿ���������ʱ�ͷ��������ڴ�
    IsReleased                        As Boolean                                '�Ƿ��Ѿ����ͷ�
End Type
'�����ڴ����ļ�¼
Private m_atMemRecords()              As ALLOCATED_MEMORY_RECORD
'�ڴ�����¼������
Private m_lRecordCount                As Long
'�Ƿ���ʹ���ļ�ӳ�䷽ʽ
Private m_fIsUsingFileMap             As Boolean
'=======================================================================================================================
'����Ϊ���ڲ�˽�б���
'=======================================================================================================================

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'=======================================================================================================================
'����Ϊ������
'=======================================================================================================================
'�Ƿ���ʹ���ļ�ӳ�䷽ʽ
Public Property Get IsUsingFileMap() As Boolean
    IsUsingFileMap = m_fIsUsingFileMap
End Property

'=======================================================================================================================
'����Ϊ������
'=======================================================================================================================
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'=======================================================================================================================
'����Ϊ�๫�к���
'=======================================================================================================================
'��Ŀ������з���һ�� lSize ��С���ڴ��
'����ɹ��򷵻�һ���ڴ����ļ�¼����
'���ʧ���򷵻� -1
Public Function Allocate(ByVal lSize As Long, ByRef hMem As Long, Optional ByVal lTargetProcessID As Long = -1, Optional fAutoRelease As Boolean = True) As Long
    On Error GoTo Error_Handler
    Dim tMemRecord As ALLOCATED_MEMORY_RECORD
    If AllocateMemory(lTargetProcessID, lSize, fAutoRelease, tMemRecord) Then
        m_lRecordCount = m_lRecordCount + 1
        ReDim Preserve m_atMemRecords(m_lRecordCount)
        m_atMemRecords(m_lRecordCount) = tMemRecord
        hMem = m_atMemRecords(m_lRecordCount).AllocatedAddress
        Allocate = m_lRecordCount
    Else
        Allocate = -1
    End If
    Exit Function
Error_Handler:
End Function

'�ͷ�lIndex��¼������ָ���ڴ��¼��������ڴ��ַ
Public Function Release(ByVal lIndex As Long) As Boolean
    On Error GoTo Error_Handler
    If lIndex >= 0 And lIndex <= m_lRecordCount Then
        Release = ReleaseMemory(m_atMemRecords(lIndex))
    End If
    Exit Function
Error_Handler:
End Function

'=======================================================================================================================
'����Ϊ�๫������
'=======================================================================================================================
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'=======================================================================================================================
'����Ϊ�ڲ�����
'=======================================================================================================================
'�����ڴ�
Private Function AllocateMemory(ByVal lTargetProcessID As Long, ByVal lSize As Long, ByVal fAutoRelease As Boolean, tMemRecord As ALLOCATED_MEMORY_RECORD) As Boolean
    With tMemRecord
        .AutoReleaseOnExit = fAutoRelease
        .AllocatedSize = lSize
        .IsReleased = False
        If m_fIsUsingFileMap Then
            .hFile = CreateFileMapping(-1, ByVal 0, PAGE_READWRITE, 0, lSize, GetGUID)
            .AllocatedAddress = MapViewOfFile(.hFile, FILE_MAP_ALL_ACCESS, 0, 0, 0)
        Else
            .TargetProcessID = lTargetProcessID
            Dim hProcess As Long
            hProcess = GetProcessHandle(lTargetProcessID)
            .AllocatedAddress = VirtualAllocEx(hProcess, ByVal 0, lSize, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
            CloseHandle hProcess
        End If
        AllocateMemory = (.AllocatedAddress <> 0)
    End With
End Function

'�ͷ�ָ���ڴ�
Private Function ReleaseMemory(tMemRecord As ALLOCATED_MEMORY_RECORD) As Boolean
    With tMemRecord
        If .IsReleased Then
            ReleaseMemory = True
            Exit Function
        End If
        If m_fIsUsingFileMap Then
            UnmapViewOfFile .AllocatedAddress
            ReleaseMemory = (CloseHandle(.hFile) <> 0)
        Else
            Dim hProcess As Long
            hProcess = GetProcessHandle(.TargetProcessID)
            ReleaseMemory = (VirtualFreeEx(hProcess, ByVal .AllocatedAddress, 0, MEM_RELEASE) <> 0)
            CloseHandle hProcess
        End If
        .IsReleased = ReleaseMemory
    End With
End Function

'��ý��̾��
Private Function GetProcessHandle(ByVal pid As Long) As Long
    GetProcessHandle = OpenProcess(PROCESS_ALL_ACCESS, 0&, IIf(pid = -1, GetCurrentProcessId, pid))
End Function

'��õ�ǰWindows�汾
Private Function GetWinVersion() As Boolean
    On Error GoTo Error_Handler
    Dim t As OSVERSIONINFO
    GetWinVersion = GetVersionEx(t) <> 0
    m_fIsUsingFileMap = ((t.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS) And t.dwPlatformId <> VER_PLATFORM_WIN32s)
    Exit Function
Error_Handler:
End Function

'���һ��ȫ��Ψһ��ʶ
Private Function GetGUID() As String
    Dim abGUID(16) As Byte
    GetGUID = String(255, " ")
    CoCreateGuid abGUID(0)
    StringFromGUID2 abGUID(0), GetGUID, 255
    GetGUID = StrConv(Trim(GetGUID), vbFromUnicode)
End Function

'=======================================================================================================================
'����Ϊ�ڲ�����
'=======================================================================================================================
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'=======================================================================================================================
'����Ϊ���ʼ�������ٹ���
'=======================================================================================================================
'���ʼ��
Private Sub Class_Initialize()
    m_lRecordCount = -1
    If GetWinVersion Then
    End If
End Sub

'������
Private Sub Class_Terminate()
    Dim i As Long
    If m_lRecordCount >= 0 Then
        For i = 0 To UBound(m_atMemRecords)
            If m_atMemRecords(i).AutoReleaseOnExit Then
                Call ReleaseMemory(m_atMemRecords(i))
            End If
        Next
    End If
End Sub
                                                                         
'=======================================================================================================================
'����Ϊ���ʼ�������ٹ���
'=======================================================================================================================