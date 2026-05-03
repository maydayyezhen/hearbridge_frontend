import { http } from '@kit.NetworkKit'
import { AppConfig } from '../common/constants/AppConfig'
import { getStoredToken } from '../common/auth/AuthStorage'
import {
  readVideoBytes,
  resolveSafeVideoUploadName,
  resolveVideoMimeType
} from '../common/file/VideoFileReader'
import {
  SemanticCorrectionRequest,
  SemanticCorrectionResult,
  SemanticRemovedSegment,
  SemanticSelectedSegment,
  SentenceSegmentResult,
  SentenceSegmentTopKItem,
  SentenceVideoRecognizeResult
} from '../model/SignVideoModels'

const MULTIPART_BOUNDARY_PREFIX: string = '----HearBridgeSignVideo'

export class SignVideoApi {
  /**
   * 上传句子视频并进行快速识别。
   *
   * @param fileUri 本地视频 URI
   * @param fileName 文件名，必须带后缀
   * @returns 快速识别结果
   */
  static async recognizeVideo(fileUri: string, fileName: string): Promise<SentenceVideoRecognizeResult> {
    const fileBytes = readVideoBytes(fileUri)
    if (fileBytes.byteLength <= 0) {
      throw new Error('视频读取失败，请重新选择。')
    }

    const boundary = `${MULTIPART_BOUNDARY_PREFIX}${Date.now()}`
    const safeFileName = resolveSafeVideoUploadName(fileName)
    const mimeType = resolveVideoMimeType(safeFileName)
    const body = SignVideoApi.buildMultipartBody(boundary, safeFileName, mimeType, fileBytes)
    const text = await SignVideoApi.postMultipart('/app/sign-video/recognize', boundary, body)
    const raw = JSON.parse(text) as Record<string, Object>
    return SignVideoApi.parseRecognizeResult(raw)
  }

  /**
   * 对快速识别结果进行 AI 候选排序与忠实自然化。
   *
   * @param recognizeResult 快速识别结果
   * @returns AI 候选排序与忠实自然化结果
   */
  static async semanticCorrect(recognizeResult: SentenceVideoRecognizeResult): Promise<SemanticCorrectionResult> {
    const request = new SemanticCorrectionRequest()
    request.rawSequence = recognizeResult.rawSequence
    request.rawTextZh = recognizeResult.rawTextZh
    request.segmentTopK = recognizeResult.segmentTopK

    const text = await SignVideoApi.postJson('/app/sign-video/semantic-correct', request)
    const raw = JSON.parse(text) as Record<string, Object>
    return SignVideoApi.parseSemanticCorrectionResult(raw)
  }

  private static async postJson(path: string, body: Object): Promise<string> {
    let httpRequest = http.createHttp()
    try {
      const token = getStoredToken().trim()
      const headers: Record<string, string> = {
        'Content-Type': 'application/json'
      }
      SignVideoApi.attachAuthHeaders(headers, token)

      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: http.RequestMethod.POST,
          header: headers,
          extraData: JSON.stringify(body),
          connectTimeout: 10000,
          readTimeout: 60000
        }
      )

      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(responseText.length > 0 ? responseText : `请求失败，状态码：${response.responseCode}`)
      }
      return responseText
    } finally {
      httpRequest.destroy()
    }
  }

  private static async postMultipart(path: string, boundary: string, body: ArrayBuffer): Promise<string> {
    let httpRequest = http.createHttp()
    try {
      const token = getStoredToken().trim()
      const headers: Record<string, string> = {
        'Content-Type': `multipart/form-data; boundary=${boundary}`
      }
      SignVideoApi.attachAuthHeaders(headers, token)

      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: http.RequestMethod.POST,
          header: headers,
          extraData: body,
          connectTimeout: 10000,
          readTimeout: 60000
        }
      )

      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(responseText.length > 0 ? responseText : `请求失败，状态码：${response.responseCode}`)
      }
      return responseText
    } finally {
      httpRequest.destroy()
    }
  }

  private static buildMultipartBody(
    boundary: string,
    fileName: string,
    mimeType: string,
    fileBytes: ArrayBuffer
  ): ArrayBuffer {
    const headerText = `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n` +
      `Content-Type: ${mimeType}\r\n\r\n`
    const footerText = `\r\n--${boundary}--\r\n`

    return SignVideoApi.mergeBuffers([
      SignVideoApi.asciiStringToBuffer(headerText),
      fileBytes,
      SignVideoApi.asciiStringToBuffer(footerText)
    ])
  }

  private static asciiStringToBuffer(value: string): ArrayBuffer {
    const buffer = new ArrayBuffer(value.length)
    const view = new Uint8Array(buffer)
    for (let index = 0; index < value.length; index++) {
      view[index] = value.charCodeAt(index) & 0xFF
    }
    return buffer
  }

  private static mergeBuffers(parts: ArrayBuffer[]): ArrayBuffer {
    let totalLength = 0
    parts.forEach((part: ArrayBuffer) => {
      totalLength += part.byteLength
    })

    const merged = new ArrayBuffer(totalLength)
    const target = new Uint8Array(merged)
    let offset = 0
    parts.forEach((part: ArrayBuffer) => {
      target.set(new Uint8Array(part), offset)
      offset += part.byteLength
    })
    return merged
  }

  private static attachAuthHeaders(headers: Record<string, string>, token: string): void {
    if (token.length === 0) {
      return
    }

    headers['Authorization'] = `Bearer ${token}`
    headers['token'] = token
  }

  private static parseRecognizeResult(source: Record<string, Object>): SentenceVideoRecognizeResult {
    const result = new SentenceVideoRecognizeResult()
    result.status = SignVideoApi.readString(source, 'status')
    result.mode = SignVideoApi.readString(source, 'mode')
    result.rawSequence = SignVideoApi.readStringArray(source, 'rawSequence')
    result.rawDisplayZh = SignVideoApi.readStringArray(source, 'rawDisplayZh')
    result.rawTextZh = SignVideoApi.readString(source, 'rawTextZh')
    result.elapsedMs = SignVideoApi.readNumber(source, 'elapsedMs')

    const segments: SentenceSegmentResult[] = []
    SignVideoApi.readArray(source, 'segmentTopK').forEach((item: Object) => {
      segments.push(SignVideoApi.parseSegmentResult(item))
    })
    result.segmentTopK = segments
    return result
  }

  private static parseSegmentResult(item: Object): SentenceSegmentResult {
    const source = item as Record<string, Object>
    const result = new SentenceSegmentResult()
    result.segmentIndex = SignVideoApi.readNumber(source, 'segmentIndex')
    result.startFrame = SignVideoApi.readNumber(source, 'startFrame')
    result.endFrame = SignVideoApi.readNumber(source, 'endFrame')
    result.rawLabel = SignVideoApi.readString(source, 'rawLabel')
    result.rawLabelZh = SignVideoApi.readString(source, 'rawLabelZh')
    result.avgConfidence = SignVideoApi.readNumber(source, 'avgConfidence')
    result.maxConfidence = SignVideoApi.readNumber(source, 'maxConfidence')

    const topKItems: SentenceSegmentTopKItem[] = []
    SignVideoApi.readArray(source, 'topK').forEach((topKItem: Object) => {
      topKItems.push(SignVideoApi.parseTopKItem(topKItem))
    })
    result.topK = topKItems
    return result
  }

  private static parseTopKItem(item: Object): SentenceSegmentTopKItem {
    const source = item as Record<string, Object>
    const result = new SentenceSegmentTopKItem()
    result.label = SignVideoApi.readString(source, 'label')
    result.labelZh = SignVideoApi.readString(source, 'labelZh')
    result.avgProb = SignVideoApi.readNumber(source, 'avgProb')
    result.maxProb = SignVideoApi.readNumber(source, 'maxProb')
    result.hitCount = SignVideoApi.readNumber(source, 'hitCount')
    return result
  }

  private static parseSemanticCorrectionResult(source: Record<string, Object>): SemanticCorrectionResult {
    const result = new SemanticCorrectionResult()
    result.rawSequence = SignVideoApi.readStringArray(source, 'rawSequence')
    result.rawTextZh = SignVideoApi.readString(source, 'rawTextZh')
    result.selectedCandidateId = SignVideoApi.readString(source, 'selectedCandidateId')
    result.correctedGlossSequence = SignVideoApi.readStringArray(source, 'correctedGlossSequence')
    result.correctedSequence = SignVideoApi.readStringArray(source, 'correctedSequence')
    if (result.correctedSequence.length === 0 && result.correctedGlossSequence.length > 0) {
      result.correctedSequence = result.correctedGlossSequence
    }
    if (result.correctedGlossSequence.length === 0 && result.correctedSequence.length > 0) {
      result.correctedGlossSequence = result.correctedSequence
    }
    result.correctedTextZh = SignVideoApi.readString(source, 'correctedTextZh')
    result.englishSentence = SignVideoApi.readString(source, 'englishSentence')
    result.chineseTranslation = SignVideoApi.readString(source, 'chineseTranslation')
    result.translationConfidence = SignVideoApi.readString(source, 'translationConfidence')
    result.isIncomplete = SignVideoApi.readBoolean(source, 'isIncomplete')
    result.translationNote = SignVideoApi.readString(source, 'translationNote')
    result.correctionApplied = SignVideoApi.readBoolean(source, 'correctionApplied')
    result.reason = SignVideoApi.readString(source, 'reason')
    result.reasonZh = SignVideoApi.readString(source, 'reasonZh')
    result.fallback = SignVideoApi.readBoolean(source, 'fallback')

    const selectedSegments: SemanticSelectedSegment[] = []
    SignVideoApi.readArray(source, 'selectedSegments').forEach((item: Object) => {
      selectedSegments.push(SignVideoApi.parseSelectedSegment(item))
    })
    result.selectedSegments = selectedSegments

    const removedSegments: SemanticRemovedSegment[] = []
    SignVideoApi.readArray(source, 'removedSegments').forEach((item: Object) => {
      removedSegments.push(SignVideoApi.parseRemovedSegment(item))
    })
    result.removedSegments = removedSegments

    return result
  }

  private static parseSelectedSegment(item: Object): SemanticSelectedSegment {
    const source = item as Record<string, Object>
    const result = new SemanticSelectedSegment()
    result.segmentIndex = SignVideoApi.readNumber(source, 'segmentIndex')
    result.rawLabel = SignVideoApi.readString(source, 'rawLabel')
    result.selectedLabel = SignVideoApi.readString(source, 'selectedLabel')
    result.action = SignVideoApi.readString(source, 'action')
    return result
  }

  private static parseRemovedSegment(item: Object): SemanticRemovedSegment {
    const source = item as Record<string, Object>
    const result = new SemanticRemovedSegment()
    result.segmentIndex = SignVideoApi.readNumber(source, 'segmentIndex')
    result.rawLabel = SignVideoApi.readString(source, 'rawLabel')
    result.rawLabelZh = SignVideoApi.readString(source, 'rawLabelZh')
    result.reason = SignVideoApi.readString(source, 'reason')
    result.reasonZh = SignVideoApi.readString(source, 'reasonZh')
    return result
  }

  private static readArray(source: Record<string, Object>, key: string): Object[] {
    const value = source[key]
    if (Array.isArray(value)) {
      return value as Object[]
    }
    return []
  }

  private static readStringArray(source: Record<string, Object>, key: string): string[] {
    const result: string[] = []
    SignVideoApi.readArray(source, key).forEach((item: Object) => {
      if (typeof item === 'string') {
        result.push(item)
      } else if (typeof item === 'number' || typeof item === 'boolean') {
        result.push(String(item))
      }
    })
    return result
  }

  private static readString(source: Record<string, Object>, key: string): string {
    const value = source[key]
    if (typeof value === 'string') {
      return value
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value)
    }
    return ''
  }

  private static readNumber(source: Record<string, Object>, key: string): number {
    const value = source[key]
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : 0
    }
    return 0
  }

  private static readBoolean(source: Record<string, Object>, key: string): boolean {
    const value = source[key]
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'string') {
      return value === 'true'
    }
    return false
  }
}
