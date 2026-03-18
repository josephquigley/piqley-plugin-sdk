import PiqleyCore

/// Curated keys for reading original image metadata (EXIF, IPTC, TIFF, XMP).
///
/// All raw values use "Group:Tag" format (e.g. `"TIFF:Model"`, `"IPTC:Keywords"`).
public enum ImageMetadataKey: String, StateKey {
    public static let namespace = ReservedName.original

    // MARK: - TIFF

    case make = "TIFF:Make"
    case model = "TIFF:Model"
    case orientation = "TIFF:Orientation"
    case software = "TIFF:Software"
    case xResolution = "TIFF:XResolution"
    case yResolution = "TIFF:YResolution"

    // MARK: - EXIF

    case dateTimeOriginal = "EXIF:DateTimeOriginal"
    case dateTimeDigitized = "EXIF:DateTimeDigitized"
    case exposureTime = "EXIF:ExposureTime"
    case fNumber = "EXIF:FNumber"
    case iso = "EXIF:ISOSpeedRatings"
    case focalLength = "EXIF:FocalLength"
    case focalLengthIn35mm = "EXIF:FocalLenIn35mmFilm"
    case lensModel = "EXIF:LensModel"
    case shutterSpeed = "EXIF:ShutterSpeedValue"
    case aperture = "EXIF:ApertureValue"
    case exposureProgram = "EXIF:ExposureProgram"
    case meteringMode = "EXIF:MeteringMode"
    case flash = "EXIF:Flash"
    case whiteBalance = "EXIF:WhiteBalance"
    case exposureCompensation = "EXIF:ExposureBiasValue"
    case bodySerialNumber = "EXIF:BodySerialNumber"
    case lensSerialNumber = "EXIF:LensSerialNumber"
    case colorSpace = "EXIF:ColorSpace"
    case pixelXDimension = "EXIF:PixelXDimension"
    case pixelYDimension = "EXIF:PixelYDimension"

    // MARK: - IPTC

    case keywords = "IPTC:Keywords"
    case caption = "IPTC:CaptionAbstract"
    case objectName = "IPTC:ObjectName"
    case city = "IPTC:City"
    case country = "IPTC:CountryPrimaryLocationName"
    case provinceState = "IPTC:ProvinceState"
    case sublocation = "IPTC:SubLocation"
    case byline = "IPTC:By-line"
    case copyrightNotice = "IPTC:CopyrightNotice"
    case credit = "IPTC:Credit"
    case source = "IPTC:Source"
    case headline = "IPTC:Headline"
    case specialInstructions = "IPTC:SpecialInstructions"
    case dateCreated = "IPTC:DateCreated"

    // MARK: - XMP

    case title = "XMP:Title"
    case xmpDescription = "XMP:Description"
    case creator = "XMP:Creator"
    case rights = "XMP:Rights"
    case rating = "XMP:Rating"
    case label = "XMP:Label"
}
