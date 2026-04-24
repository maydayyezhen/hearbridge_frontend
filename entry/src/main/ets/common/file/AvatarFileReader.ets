import common from '@ohos.app.ability.common'
import fileIo from '@ohos.file.fs'
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import dataSharePredicates from '@ohos.data.dataSharePredicates'

function isPhotoAssetUri(uri: string): boolean {
  return uri.indexOf('file://media/Photo') === 0 || uri.indexOf('datashare://') === 0
}

function sliceBuffer(buffer: ArrayBuffer, size: number): ArrayBuffer {
  if (size >= buffer.byteLength) {
    return buffer
  }
  return buffer.slice(0, size)
}

async function readPhotoAssetData(context: common.UIAbilityContext, sourceUri: string): Promise<ArrayBuffer> {
  const helper = photoAccessHelper.getPhotoAccessHelper(context)
  const predicates = new dataSharePredicates.DataSharePredicates()
  predicates.equalTo(photoAccessHelper.PhotoKeys.URI, sourceUri)
  const fetchResult = await helper.getAssets({
    fetchColumns: [photoAccessHelper.PhotoKeys.URI],
    predicates: predicates
  } as photoAccessHelper.FetchOptions)

  try {
    if (fetchResult.getCount() < 1) {
      return new ArrayBuffer(0)
    }

    const asset = await fetchResult.getFirstObject()
    return await new Promise<ArrayBuffer>((resolve, reject) => {
      photoAccessHelper.MediaAssetManager.requestImageData(
        context,
        asset,
        { deliveryMode: photoAccessHelper.DeliveryMode.FAST_MODE } as photoAccessHelper.RequestOptions,
        {
          onDataPrepared: (data: ArrayBuffer): void => {
            resolve(data)
          }
        }
      ).catch((error: Error) => reject(error))
    })
  } finally {
    try {
      fetchResult.close()
    } catch (_error) {
    }
    try {
      helper.release()
    } catch (_error) {
    }
  }
}

function readGenericFileData(sourceUri: string): ArrayBuffer {
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

export async function readAvatarBytes(context: common.UIAbilityContext, fileUri: string): Promise<ArrayBuffer> {
  if (isPhotoAssetUri(fileUri)) {
    return await readPhotoAssetData(context, fileUri)
  }
  return readGenericFileData(fileUri)
}

export function resolveAvatarFileName(fileUri: string): string {
  const cleanUri = fileUri.split('#')[0].split('?')[0]
  const slashIndex = Math.max(cleanUri.lastIndexOf('/'), cleanUri.lastIndexOf('\\'))
  const name = slashIndex >= 0 ? cleanUri.substring(slashIndex + 1) : cleanUri
  if (name.trim().length > 0) {
    return name
  }
  return 'avatar.jpg'
}

export function resolveAvatarMimeType(fileName: string): string {
  const lowerName = fileName.toLowerCase()
  if (lowerName.endsWith('.png')) {
    return 'image/png'
  }
  if (lowerName.endsWith('.webp')) {
    return 'image/webp'
  }
  return 'image/jpeg'
}
