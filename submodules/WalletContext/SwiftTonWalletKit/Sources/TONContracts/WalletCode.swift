import Foundation
import TONCore

/// Compiled wallet contract code.
///
/// Extracted verbatim from the reference sources (`WalletV5R1.source.ts`,
/// `WalletV4R2.source.ts`) rather than transcribed. The code hash determines the
/// contract address, so a single wrong character here would silently derive wrong
/// addresses for every wallet.
public enum WalletCode {
    /// WalletV5R1 (w5), the current recommended version.
    ///
    /// Code hash: `20834b7b72b112147e1b2fb457b84e74d1a30f04f737d4f62a668e9552d2b72f`
    public static let v5r1Base64 = "te6cckECFAEAAoEAART/APSkE/S88sgLAQIBIAINAgFIAwQC3NAg10nBIJFbj2Mg1wsfIIIQZXh0br0hghBzaW50vbCSXwPgghBleHRuuo60gCDXIQHQdNch+kAw+kT4KPpEMFi9kVvg7UTQgQFB1yH0BYMH9A5voTGRMOGAQNchcH/bPOAxINdJgQKAuZEw4HDiEA8CASAFDAIBIAYJAgFuBwgAGa3OdqJoQCDrkOuF/8AAGa8d9qJoQBDrkOuFj8ACAUgKCwAXsyX7UTQcdch1wsfgABGyYvtRNDXCgCAAGb5fD2omhAgKDrkPoCwBAvIOAR4g1wsfghBzaWduuvLgin8PAeaO8O2i7fshgwjXIgKDCNcjIIAg1yHTH9Mf0x/tRNDSANMfINMf0//XCgAK+QFAzPkQmiiUXwrbMeHywIffArNQB7Dy0IRRJbry4IVQNrry4Ib4I7vy0IgikvgA3gGkf8jKAMsfAc8Wye1UIJL4D95w2zzYEAP27aLt+wL0BCFukmwhjkwCIdc5MHCUIccAs44tAdcoIHYeQ2wg10nACPLgkyDXSsAC8uCTINcdBscSwgBSMLDy0InXTNc5MAGk6GwShAe78uCT10rAAPLgk+1V4tIAAcAAkVvg69csCBQgkXCWAdcsCBwS4lIQseMPINdKERITAJYB+kAB+kT4KPpEMFi68uCR7UTQgQFB1xj0BQSdf8jKAEAEgwf0U/Lgi44UA4MH9Fvy4Iwi1woAIW4Bs7Dy0JDiyFADzxYS9ADJ7VQAcjDXLAgkji0h8uCS0gDtRNDSAFETuvLQj1RQMJExnAGBAUDXIdcKAPLgjuLIygBYzxbJ7VST8sCN4gAQk1vbMeHXTNC01sNe"

    /// WalletV4R2, still widely deployed.
    ///
    /// Code hash: `feb5ff6820e2ff0d9483e7e0d62c817d846789fb4ae580c878866d959dabd5c0`
    public static let v4r2Base64 = "te6cckECFAEAAtQAART/APSkE/S88sgLAQIBIAIPAgFIAwYC5tAB0NMDIXGwkl8E4CLXScEgkl8E4ALTHyGCEHBsdWe9IoIQZHN0cr2wkl8F4AP6QDAg+kQByMoHy//J0O1E0IEBQNch9AQwXIEBCPQKb6Exs5JfB+AF0z/IJYIQcGx1Z7qSODDjDQOCEGRzdHK6kl8G4w0EBQB4AfoA9AQw+CdvIjBQCqEhvvLgUIIQcGx1Z4MesXCAGFAEywUmzxZY+gIZ9ADLaRfLH1Jgyz8gyYBA+wAGAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+ICASAHDgIBIAgNAgFYCQoAPbKd+1E0IEBQNch9AQwAsjKB8v/ydABgQEI9ApvoTGACASALDAAZrc52omhAIGuQ64X/wAAZrx32omhAEGuQ64WPwAARuMl+1E0NcLH4AFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQE+PKDCNcYINMf0x/THwL4I7vyZO1E0NMf0x/T//QE0VFDuvKhUVG68qIF+QFUEGT5EPKj+AAkpMjLH1JAyx9SMMv/UhD0AMntVPgPAdMHIcAAn2xRkyDXSpbTB9QC+wDoMOAhwAHjACHAAuMAAcADkTDjDQOkyMsfEssfy/8QERITAG7SB/oA1NQi+QAFyMoHFcv/ydB3dIAYyMsFywIizxZQBfoCFMtrEszMyXP7AMhAFIEBCPRR8qcCAHCBAQjXGPoA0z/IVCBHgQEI9FHyp4IQbm90ZXB0gBjIywXLAlAGzxZQBPoCFMtqEssfyz/Jc/sAAgBsgQEI1xj6ANM/MFIkgQEI9Fnyp4IQZHN0cnB0gBjIywXLAlAFzxZQA/oCE8tqyx8Syz/Jc/sAAAr0AMntVAj45Sg="

    /// The wallet-v5-experimental contract ("w5 experimental"), which adds one-time
    /// public-key rotation on top of V5R1.
    ///
    /// Built from `tolk-vm/wallet-v5-experimental` at commit
    /// `b420256f2fd78844a31260831616c1fab7acd0db` with Acton 1.1.0, and taken verbatim
    /// from the reference implementation that deploys it.
    ///
    /// Code hash: `99cca09ed5dfc604fbfe67e1d2d69a00ba74852b2365a23b49628b5633797898`
    public static let v5ExperimentalBase64 = "te6ccgECFQEAA34AART/APSkE/S88sgLAQIBIAIDAgFIBAUC4PIggwjXIgGDCNcjINcsI5tLO3Ty4IrTH9Mf0x/0BNIA7UTQ0gDTHyDTH9P/9AUMyM75FkDd+RDy4IcJbhKx8uCEUUS68uCFUFe68uCGAvgjvPLgiPgApMjPg8sfE87J7VT4D3AibpEy4w6Ogts84FsQEQP40CDXLCObS3Okj3Ah10mBAoC+kVvhIYMI1yICgwjXI+1E0NIA0x8g0x/T//QFBsjO+RZAiPkQkl8G4QNuErHy4IQC0x/TH9Mf9ATSAFE3uvLghVBHuvLghgH4I7zy4IgDpMjPg8sfEs7J7VRwIW6RMeMOAo6DAds8kVvi4AYRBwIBIAgJAGhwItc5MI4iINdLwALy4JPAKPLgk9csIHYeQ2zy4JPXTNc5MAGkIccAEuYwhAe78uCTAe1VAfQx1ywjK8OjdI7u+JL6RPgo+kQwWL2RW+DtRNCBAUHXIfQFgwf0Dm+hMZEw4dM/MfQE0gB/I26RM440cCTXOTCOIiDXS8AC8uCTwCjy4JPXLCB2HkNs8uCT10zXOTABpCHHABLmMIQHu/LgkwPtVeIBjoMB2zyRW+LgMBECASAKCwAZvl8PaiaECAoOuQ+gLAIBbgwNAgFIDg8AF63OdqJoaaAY64X/wAAXrx32omhpkBjrhY/AABezJftRNDTADHXCx+AAEbJi+1E0NcKAIAB2cCPXOTCOKSDXS8AC8uCTwCjy4JPXLCB2HkNs8uCT1NcLB3Kw8uCJ1zkwAaQhxwAS5jCEB7vy4JMC7VUBku2i7fvrIdcsCBSOLvpIMPpE+Cj6RDBYuvLgke1E0IEBQdcY9ATIz4NQQoMH9FPy4IsByM70AM7J7VTjDiHXSpNb2zHhAddM0AESAuLXLAgcjunXLAgkjmHXLAgsk/LAjeEh8tCW10zQ0/+DCNcY0e1E0NZA0//0BNcKAFElvfLglAHy0Jf4KPpEyIvEtFWV9ST1RBVElPTozxYSygfL/89QVBA0+RHy4JXIzhLL//QAz4PJ7VQB1DEB4w3jDRMUAFwh8uCS7UTQAdcKAAHSACCBAUDXIfQFUSO98uCPIpExlQFu8tCO4gHIygDOye1UAG76SDD6RPgo+kQwWLry4JHtRNDSAIEBQNcY9ARQRIMH9Fvy4IwilSBu8tCQ3wLIygDO9ADOye1U"

    /// Expected code hashes, asserted by the tests so a corrupted constant fails loudly
    /// rather than producing plausible-looking wrong addresses.
    public static let v5r1CodeHash = "20834b7b72b112147e1b2fb457b84e74d1a30f04f737d4f62a668e9552d2b72f"
    public static let v4r2CodeHash = "feb5ff6820e2ff0d9483e7e0d62c817d846789fb4ae580c878866d959dabd5c0"
    public static let v5ExperimentalCodeHash = "99cca09ed5dfc604fbfe67e1d2d69a00ba74852b2365a23b49628b5633797898"

    public static let v5r1: Cell = {
        // Force-unwrapped deliberately: a failure here means the embedded constant is
        // corrupt, which is a programming error, not a runtime condition.
        try! Cell.fromBase64(v5r1Base64)
    }()

    public static let v4r2: Cell = {
        try! Cell.fromBase64(v4r2Base64)
    }()

    public static let v5Experimental: Cell = {
        try! Cell.fromBase64(v5ExperimentalBase64)
    }()
}
