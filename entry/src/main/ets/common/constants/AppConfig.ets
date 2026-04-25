export class AppConfig {
  static readonly BASE_URL: string = 'http://192.168.43.6:8080'

  static readonly MINIO_BASE_URL: string = 'http://192.168.43.6:9000'

  static readonly MINIO_BUCKET: string = 'cwasa-static'

  static readonly GESTURE_WS_URL: string = 'ws://192.168.43.6:8000/ws/gesture'

  static readonly DATASET_WS_URL: string = 'ws://192.168.43.6:8000/ws/dataset'

  static buildMinioBucketBaseUrl(): string {
    return `${AppConfig.MINIO_BASE_URL}/${AppConfig.MINIO_BUCKET}`
  }

  static buildAssetUrl(objectKey: string): string {
    if (!objectKey || objectKey.trim().length === 0) {
      return ''
    }

    const normalizedKey = objectKey.startsWith('/') ? objectKey.slice(1) : objectKey
    return `${AppConfig.buildMinioBucketBaseUrl()}/${normalizedKey}`
  }

  static buildRuntimeBaseUrl(): string {
    return `${AppConfig.buildMinioBucketBaseUrl()}/runtime/`
  }

  static buildAvatarJarBaseUrl(): string {
    return `${AppConfig.buildMinioBucketBaseUrl()}/avatar/avatars/`
  }

  static buildDemoSigmlBaseUrl(): string {
    return `${AppConfig.buildMinioBucketBaseUrl()}/sigml/demo/`
  }

  static normalizeAssetUrl(rawUrl: string, objectKey: string): string {
    const safeRawUrl = rawUrl ? rawUrl.trim() : ''
    if (safeRawUrl.length === 0) {
      return AppConfig.buildAssetUrl(objectKey)
    }

    if (
      safeRawUrl.startsWith('http://127.0.0.1') ||
      safeRawUrl.startsWith('https://127.0.0.1') ||
      safeRawUrl.indexOf('://localhost') >= 0
    ) {
      const pathStart = safeRawUrl.indexOf('/', safeRawUrl.indexOf('://') + 3)
      if (pathStart >= 0) {
        return `${AppConfig.MINIO_BASE_URL}${safeRawUrl.slice(pathStart)}`
      }
    }

    if (!safeRawUrl.startsWith('http://') && !safeRawUrl.startsWith('https://')) {
      return AppConfig.buildAssetUrl(safeRawUrl)
    }

    return safeRawUrl
  }
}
