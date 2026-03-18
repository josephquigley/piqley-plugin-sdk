import Testing
@testable import PiqleyPluginSDK

// MARK: - Custom StateKey enum for testing

private enum MyKeys: String, StateKey {
    static let namespace = "my-plugin"
    case keywords
    case caption
    case rating
}

// MARK: - Tests

@Test func customStateKeyNamespace() {
    #expect(MyKeys.namespace == "my-plugin")
}

@Test func customStateKeyRawValues() {
    #expect(MyKeys.keywords.rawValue == "keywords")
    #expect(MyKeys.caption.rawValue == "caption")
    #expect(MyKeys.rating.rawValue == "rating")
}

@Test func imageMetadataKeyNamespace() {
    #expect(ImageMetadataKey.namespace == "original")
}

// MARK: - TIFF spot checks

@Test func imageMetadataKeyTIFF() {
    #expect(ImageMetadataKey.make.rawValue == "TIFF:Make")
    #expect(ImageMetadataKey.model.rawValue == "TIFF:Model")
    #expect(ImageMetadataKey.orientation.rawValue == "TIFF:Orientation")
    #expect(ImageMetadataKey.software.rawValue == "TIFF:Software")
    #expect(ImageMetadataKey.xResolution.rawValue == "TIFF:XResolution")
    #expect(ImageMetadataKey.yResolution.rawValue == "TIFF:YResolution")
}

// MARK: - EXIF spot checks

@Test func imageMetadataKeyEXIF() {
    #expect(ImageMetadataKey.dateTimeOriginal.rawValue == "EXIF:DateTimeOriginal")
    #expect(ImageMetadataKey.fNumber.rawValue == "EXIF:FNumber")
    #expect(ImageMetadataKey.iso.rawValue == "EXIF:ISOSpeedRatings")
    #expect(ImageMetadataKey.focalLengthIn35mm.rawValue == "EXIF:FocalLenIn35mmFilm")
    #expect(ImageMetadataKey.shutterSpeed.rawValue == "EXIF:ShutterSpeedValue")
    #expect(ImageMetadataKey.aperture.rawValue == "EXIF:ApertureValue")
    #expect(ImageMetadataKey.exposureCompensation.rawValue == "EXIF:ExposureBiasValue")
    #expect(ImageMetadataKey.pixelXDimension.rawValue == "EXIF:PixelXDimension")
    #expect(ImageMetadataKey.pixelYDimension.rawValue == "EXIF:PixelYDimension")
}

// MARK: - IPTC spot checks

@Test func imageMetadataKeyIPTC() {
    #expect(ImageMetadataKey.keywords.rawValue == "IPTC:Keywords")
    #expect(ImageMetadataKey.caption.rawValue == "IPTC:CaptionAbstract")
    #expect(ImageMetadataKey.country.rawValue == "IPTC:CountryPrimaryLocationName")
    #expect(ImageMetadataKey.sublocation.rawValue == "IPTC:SubLocation")
    #expect(ImageMetadataKey.dateCreated.rawValue == "IPTC:DateCreated")
}

// MARK: - XMP spot checks

@Test func imageMetadataKeyXMP() {
    #expect(ImageMetadataKey.title.rawValue == "XMP:Title")
    #expect(ImageMetadataKey.xmpDescription.rawValue == "XMP:Description")
    #expect(ImageMetadataKey.rating.rawValue == "XMP:Rating")
    #expect(ImageMetadataKey.label.rawValue == "XMP:Label")
}
