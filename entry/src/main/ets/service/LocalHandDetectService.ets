import { LocalHandDetectResult } from '../model/LocalHandModels'
import handDetector from 'libentry.so'

export class LocalHandDetectService {
  async detectFromJpeg(
    jpegBytes: ArrayBuffer,
    width: number,
    height: number,
    rotation: number
  ): Promise<LocalHandDetectResult> {
    return Promise.resolve(
      handDetector.detectFromJpeg(jpegBytes, width, height, rotation) as LocalHandDetectResult
    )
  }
}