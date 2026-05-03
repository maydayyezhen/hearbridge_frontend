/**
 * 句子视频识别 TopK 候选项。
 */
export class SentenceSegmentTopKItem {
  label: string = ''
  labelZh: string = ''
  avgProb: number = 0
  maxProb: number = 0
  hitCount: number = 0
}

/**
 * 句子视频识别词段结果。
 */
export class SentenceSegmentResult {
  segmentIndex: number = 0
  startFrame: number = 0
  endFrame: number = 0
  rawLabel: string = ''
  rawLabelZh: string = ''
  avgConfidence: number = 0
  maxConfidence: number = 0
  topK: SentenceSegmentTopKItem[] = []
}

/**
 * 句子视频快速识别结果。
 */
export class SentenceVideoRecognizeResult {
  status: string = ''
  mode: string = ''
  rawSequence: string[] = []
  rawDisplayZh: string[] = []
  rawTextZh: string = ''
  segmentTopK: SentenceSegmentResult[] = []
  elapsedMs: number = 0
}

/**
 * AI 候选排序与忠实自然化请求。
 */
export class SemanticCorrectionRequest {
  rawSequence: string[] = []
  rawTextZh: string = ''
  segmentTopK: SentenceSegmentResult[] = []
}

/**
 * AI 后处理选中/删除动作。
 */
export class SemanticSelectedSegment {
  segmentIndex: number = 0
  rawLabel: string = ''
  selectedLabel: string = ''
  action: string = ''
}

/**
 * AI 删除的词段。
 */
export class SemanticRemovedSegment {
  segmentIndex: number = 0
  rawLabel: string = ''
  rawLabelZh: string = ''
  reason: string = ''
  reasonZh: string = ''
}

/**
 * AI 候选排序与忠实自然化结果。
 */
export class SemanticCorrectionResult {
  rawSequence: string[] = []
  rawTextZh: string = ''
  selectedCandidateId: string = ''
  correctedGlossSequence: string[] = []
  correctedSequence: string[] = []
  correctedTextZh: string = ''
  englishSentence: string = ''
  chineseTranslation: string = ''
  translationConfidence: string = ''
  isIncomplete: boolean = false
  translationNote: string = ''
  correctionApplied: boolean = false
  selectedSegments: SemanticSelectedSegment[] = []
  removedSegments: SemanticRemovedSegment[] = []
  reason: string = ''
  reasonZh: string = ''
  fallback: boolean = false
}
