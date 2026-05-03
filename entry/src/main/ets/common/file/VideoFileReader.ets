import fileIo from '@ohos.file.fs'

const DEFAULT_VIDEO_FILE_NAME: string = 'upload.mp4'

function sliceBuffer(buffer: ArrayBuffer, size: number): ArrayBuffer {
  if (size >= buffer.byteLength) {
    return buffer
  }
  return buffer.slice(0, size)
}

/**
 * 读取本地视频字节。
 *
 * 系统选择器返回的 URI 通常会授予临时读权限，调用方不需要额外申请存储权限。
 */
export function readVideoBytes(sourceUri: string): ArrayBuffer {
  let file: fileIo.File | null = null
  try {
    file = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY)
    const stat = fileIo.statSync(file.fd)
    const size = Number(stat.size)
    if (size <= 0) {
      return new ArrayBuffer(0)
    }

    const buffer = new ArrayBuffer(size)
    const readSize = fileIo.readSync(file.fd, buffer)
    return sliceBuffer(buffer, readSize)
  } finally {
    if (file !== null) {
      try {
        fileIo.closeSync(file)
      } catch (_error) {
      }
    }
  }
}

/**
 * 从 URI 推断上传文件名。
 */
export function resolveVideoFileName(fileUri: string): string {
  const cleanUri = fileUri.split('#')[0].split('?')[0]
  const slashIndex = Math.max(cleanUri.lastIndexOf('/'), cleanUri.lastIndexOf('\\'))
  let name = slashIndex >= 0 ? cleanUri.substring(slashIndex + 1) : cleanUri

  try {
    name = decodeURIComponent(name)
  } catch (_error) {
  }

  if (hasVideoExtension(name)) {
    return name
  }

  return DEFAULT_VIDEO_FILE_NAME
}

/**
 * 根据文件名推断视频 MIME。
 */
export function resolveVideoMimeType(fileName: string): string {
  const lowerName = fileName.toLowerCase()
  if (lowerName.endsWith('.mov')) {
    return 'video/quicktime'
  }
  if (lowerName.endsWith('.avi')) {
    return 'video/x-msvideo'
  }
  if (lowerName.endsWith('.mkv')) {
    return 'video/x-matroska'
  }
  return 'video/mp4'
}

/**
 * 为 multipart 上传构造安全文件名，保留后端需要的扩展名。
 */
export function resolveSafeVideoUploadName(fileName: string): string {
  const lowerName = fileName.toLowerCase()
  if (lowerName.endsWith('.mov')) {
    return 'sign-video-upload.mov'
  }
  if (lowerName.endsWith('.avi')) {
    return 'sign-video-upload.avi'
  }
  if (lowerName.endsWith('.mkv')) {
    return 'sign-video-upload.mkv'
  }
  return 'sign-video-upload.mp4'
}

function hasVideoExtension(fileName: string): boolean {
  const lowerName = fileName.toLowerCase()
  return lowerName.endsWith('.mp4') ||
    lowerName.endsWith('.mov') ||
    lowerName.endsWith('.avi') ||
    lowerName.endsWith('.mkv')
}
