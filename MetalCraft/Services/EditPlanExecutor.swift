//
//  EditPlanExecutor.swift
//  MetalCraft
//
//  Translates validated, strongly-typed EditPlan contracts from the AI Creative Director
//  into concrete ProcessingPipeline nodes and photographic AdjustmentParams on iOS.
//  Enforces strict parameter bounds-checking, operation whitelisting, and defensive clamping.
//

import Foundation

// MARK: - EditPlan Execution Errors

enum EditPlanExecutionError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(String)
    case unsupportedOperationType(String)
    case missingParameter(operation: String, parameter: String)
    case operationLimitExceeded(count: Int, limit: Int)
    case invalidParameterValue(operation: String, parameter: String, details: String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported EditPlan schema version '\(version)'. Supported versions: '1.0'."
        case .unsupportedOperationType(let type):
            return "Unsupported processing operation type '\(type)'."
        case .missingParameter(let op, let param):
            return "Missing required parameter '\(param)' for operation '\(op)'."
        case .operationLimitExceeded(let count, let limit):
            return "Operation count (\(count)) exceeds the maximum safe limit (\(limit))."
        case .invalidParameterValue(let op, let param, let details):
            return "Invalid value for parameter '\(param)' in operation '\(op)': \(details)"
        }
    }
}

// MARK: - EditPlan Execution Result

struct EditPlanExecutionResult: Sendable, Equatable {
    var pipeline: ProcessingPipeline
    var adjustments: AdjustmentParams
    var outputFormat: ExportFormat
}

// MARK: - EditPlan Executor Service

final class EditPlanExecutor: Sendable {
    static let maxOperationsLimit: Int = 20
    static let supportedVersions: Set<String> = ["1.0"]
    
    init() {}
    
    /// Translates an incoming EditPlan into a ProcessingPipeline and AdjustmentParams.
    /// Throws an EditPlanExecutionError if the schema version is unsupported or parameters are malformed.
    func execute(_ plan: EditPlan) throws -> EditPlanExecutionResult {
        // 1. Validate schema version
        guard Self.supportedVersions.contains(plan.schemaVersion) else {
            throw EditPlanExecutionError.unsupportedSchemaVersion(plan.schemaVersion)
        }
        
        // 2. Validate operation count
        guard plan.operations.count <= Self.maxOperationsLimit else {
            throw EditPlanExecutionError.operationLimitExceeded(
                count: plan.operations.count,
                limit: Self.maxOperationsLimit
            )
        }
        
        // 3. Translate and clamp photographic adjustments
        let adjustments = translateAdjustments(plan.adjustments)
        
        // 4. Translate operation nodes
        var pipeline = ProcessingPipeline()
        for editOp in plan.operations {
            let processingOp = try translateOperation(editOp)
            let node = PipelineNode(
                id: editOp.id,
                operation: processingOp,
                isEnabled: editOp.enabled
            )
            pipeline.addNode(node)
        }
        
        // 5. Determine output format
        let exportFormat = parseExportFormat(plan.output.format)
        
        return EditPlanExecutionResult(
            pipeline: pipeline,
            adjustments: adjustments,
            outputFormat: exportFormat
        )
    }
    
    // MARK: - Adjustments Translation
    
    private func translateAdjustments(_ adj: EditPlanAdjustments) -> AdjustmentParams {
        AdjustmentParams(
            brightness: clamp(adj.brightness, min: -1.0, max: 1.0),
            contrast: clamp(adj.contrast, min: 0.0, max: 3.0),
            exposure: clamp(adj.exposure, min: -3.0, max: 3.0),
            saturation: clamp(adj.saturation, min: 0.0, max: 3.0),
            temperature: clamp(adj.temperature, min: -1.0, max: 1.0),
            tint: clamp(adj.tint, min: -1.0, max: 1.0),
            gamma: clamp(adj.gamma, min: 0.1, max: 3.0),
            _padding: 0.0
        )
    }
    
    // MARK: - Operation Translation
    
    private func translateOperation(_ editOp: EditPlanOperation) throws -> ProcessingOperation {
        let type = editOp.type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let params = editOp.parameters
        
        switch type {
        case "adjustments":
            let adjParams = AdjustmentParams(
                brightness: clamp(params["brightness"]?.floatValue ?? 0.0, min: -1.0, max: 1.0),
                contrast: clamp(params["contrast"]?.floatValue ?? 1.0, min: 0.0, max: 3.0),
                exposure: clamp(params["exposure"]?.floatValue ?? 0.0, min: -3.0, max: 3.0),
                saturation: clamp(params["saturation"]?.floatValue ?? 1.0, min: 0.0, max: 3.0),
                temperature: clamp(params["temperature"]?.floatValue ?? 0.0, min: -1.0, max: 1.0),
                tint: clamp(params["tint"]?.floatValue ?? 0.0, min: -1.0, max: 1.0),
                gamma: clamp(params["gamma"]?.floatValue ?? 1.0, min: 0.1, max: 3.0),
                _padding: 0.0
            )
            return .adjustments(adjParams)
            
        case "grayscale", "monochrome", "blackandwhite":
            return .grayscale
            
        case "invert", "colorinversion":
            return .invert
            
        case "gaussianblur", "blur":
            guard let sigmaVal = params["sigma"]?.floatValue ?? params["radius"]?.floatValue else {
                throw EditPlanExecutionError.missingParameter(operation: type, parameter: "sigma")
            }
            let clampedSigma = clamp(sigmaVal, min: 0.1, max: 50.0)
            return .gaussianBlur(sigma: clampedSigma)
            
        case "sharpen":
            let strength = params["strength"]?.floatValue ?? 1.0
            let clampedStrength = clamp(strength, min: 0.0, max: 2.0)
            return .sharpen(strength: clampedStrength)
            
        case "sobeledge", "edge", "edgedetection":
            let strength = params["strength"]?.floatValue ?? 1.0
            let blend = params["blend"]?.floatValue ?? 0.5
            return .sobelEdge(
                strength: clamp(strength, min: 0.0, max: 5.0),
                blend: clamp(blend, min: 0.0, max: 1.0)
            )
            
        case "pixelate", "mosaic":
            let blockSize = params["blockSize"]?.floatValue ?? params["size"]?.floatValue ?? 16.0
            return .pixelate(blockSize: clamp(blockSize, min: 1.0, max: 200.0))
            
        case "ripple":
            let config = RippleConfig(
                centerX: clamp(params["centerX"]?.floatValue ?? 0.5, min: 0.0, max: 1.0),
                centerY: clamp(params["centerY"]?.floatValue ?? 0.5, min: 0.0, max: 1.0),
                radius: clamp(params["radius"]?.floatValue ?? 0.5, min: 0.01, max: 2.0),
                strength: clamp(params["strength"]?.floatValue ?? 0.1, min: 0.0, max: 1.0),
                frequency: clamp(params["frequency"]?.floatValue ?? 20.0, min: 1.0, max: 100.0),
                phase: clamp(params["phase"]?.floatValue ?? 0.0, min: 0.0, max: 100.0)
            )
            return .ripple(config)
            
        case "swirl":
            let config = SwirlConfig(
                centerX: clamp(params["centerX"]?.floatValue ?? 0.5, min: 0.0, max: 1.0),
                centerY: clamp(params["centerY"]?.floatValue ?? 0.5, min: 0.0, max: 1.0),
                radius: clamp(params["radius"]?.floatValue ?? 0.5, min: 0.01, max: 2.0),
                strength: clamp(params["strength"]?.floatValue ?? 0.5, min: -10.0, max: 10.0)
            )
            return .swirl(config)
            
        case "convolution", "kernel":
            let kernelName = params["kernelName"]?.stringValue ?? params["name"]?.stringValue ?? "Sharpen"
            let strength = clamp(params["strength"]?.floatValue ?? 1.0, min: 0.0, max: 2.0)
            let kernel = resolveConvolutionKernel(named: kernelName)
            return .convolution(kernel, strength: strength)
            
        default:
            throw EditPlanExecutionError.unsupportedOperationType(editOp.type)
        }
    }
    
    // MARK: - Helpers
    
    private func resolveConvolutionKernel(named name: String) -> ConvolutionKernel {
        let lower = name.lowercased()
        if lower.contains("sharpen") {
            return .sharpen
        } else if lower.contains("blur") || lower.contains("gaussian") {
            return .blur
        } else if lower.contains("edge") || lower.contains("sobel") {
            return .edgeDetection
        } else if lower.contains("emboss") {
            return .emboss
        } else {
            return .identity
        }
    }
    
    private func parseExportFormat(_ raw: String) -> ExportFormat {
        switch raw.lowercased() {
        case "png": return .png
        case "heif", "heic": return .heif
        default: return .jpeg
        }
    }
    
    private func clamp(_ value: Float, min minVal: Float, max maxVal: Float) -> Float {
        max(minVal, min(maxVal, value))
    }
}
