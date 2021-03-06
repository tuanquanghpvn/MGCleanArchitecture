//
// DynamicEditProductViewModelTests.swift
// CleanArchitecture
//
// Created by Tuan Truong on 9/10/18.
// Copyright © 2018 Framgia. All rights reserved.
//

@testable import CleanArchitecture
import XCTest
import RxSwift
import RxBlocking

final class DynamicEditProductViewModelTests: XCTestCase {
    private var viewModel: DynamicEditProductViewModel!
    private var navigator: DynamicEditProductNavigatorMock!
    private var useCase: DynamicEditProductUseCaseMock!
    private var disposeBag: DisposeBag!
    private var input: DynamicEditProductViewModel.Input!
    private var output: DynamicEditProductViewModel.Output!
    private let loadTrigger = PublishSubject<DynamicEditProductViewModel.TriggerType>()
    private let updateTrigger = PublishSubject<Void>()
    private let cancelTrigger = PublishSubject<Void>()
    private let dataTrigger = PublishSubject<DynamicEditProductViewModel.DataType>()
    
    override func setUp() {
        super.setUp()
        navigator = DynamicEditProductNavigatorMock()
        useCase = DynamicEditProductUseCaseMock()
        viewModel = DynamicEditProductViewModel(navigator: navigator, useCase: useCase, product: Product())
        disposeBag = DisposeBag()
        
        input = DynamicEditProductViewModel.Input(
            loadTrigger: loadTrigger.asDriverOnErrorJustComplete(),
            updateTrigger: updateTrigger.asDriverOnErrorJustComplete(),
            cancelTrigger: cancelTrigger.asDriverOnErrorJustComplete(),
            dataTrigger: dataTrigger.asDriverOnErrorJustComplete()
        )
        output = viewModel.transform(input)
        output.nameValidation.drive().disposed(by: disposeBag)
        output.priceValidation.drive().disposed(by: disposeBag)
        output.updateEnable.drive().disposed(by: disposeBag)
        output.updatedProduct.drive().disposed(by: disposeBag)
        output.cancel.drive().disposed(by: disposeBag)
        output.error.drive().disposed(by: disposeBag)
        output.loading.drive().disposed(by: disposeBag)
        output.cells.drive().disposed(by: disposeBag)
    }
    
    func test_loadTrigger_cells_need_reload() {
        // act
        loadTrigger.onNext(.load)
        
        let args = try? output.cells.toBlocking(timeout: 1).first()
        let cells = args??.0
        let needReload = args??.1
        
        // assert
        XCTAssertEqual(cells?.count, 2)
        XCTAssertEqual(needReload, true)
    }
    
    func test_loadTrigger_cells_no_need_reload() {
        // act
        loadTrigger.onNext(.endEditing)
        
        let args = try? output.cells.toBlocking(timeout: 1).first()
        let cells = args??.0
        let needReload = args??.1
        
        // assert
        XCTAssertEqual(cells?.count, 2)
        XCTAssertEqual(needReload, false)
    }
    
    func test_cancelTrigger_dismiss() {
        // act
        cancelTrigger.onNext(())
        
        // assert
        XCTAssert(navigator.dismiss_Called)
    }
    
    func test_dataTrigger_product_name() {
        // act
        let productName = "foo"
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.name(productName))
        loadTrigger.onNext(.endEditing)
        let args = try? output.cells.toBlocking(timeout: 1).first()
        let cells = args??.0
        
        // assert
        if let dataType = cells?[0].dataType,
            case let DynamicEditProductViewModel.DataType.name(name) = dataType {
            XCTAssertEqual(name, productName)
        } else {
            XCTFail()
        }
    }
    
    func test_dataTrigger_validate_product_name() {
        // act
        let productName = "foo"
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.name(productName))
        updateTrigger.onNext(())
        
        // assert
        XCTAssert(useCase.validateName_Called)
    }
    
    func test_dataTrigger_product_price() {
        // act
        let productPrice = "1.0"
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.price(productPrice))
        loadTrigger.onNext(.endEditing)
        let args = try? output.cells.toBlocking(timeout: 1).first()
        let cells = args??.0
        
        // assert
        if let dataType = cells?[1].dataType,
            case let DynamicEditProductViewModel.DataType.price(price) = dataType {
            XCTAssertEqual(price, String(Double(productPrice) ?? 0))
        } else {
            XCTFail()
        }
    }
    
    func test_dataTrigger_validate_product_price() {
        // act
        let productPrice = "1.0"
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.price(productPrice))
        updateTrigger.onNext(())
        
        // assert
        XCTAssert(useCase.validatePrice_Called)
    }
    
    func test_loadTriggerInvoked_enableUpdateByDefault() {
        // act
        loadTrigger.onNext(.load)
        let updateEnable = try? output.updateEnable.toBlocking(timeout: 1).first()
        
        // assert
        XCTAssertEqual(updateEnable, true)
    }
    
    func test_updateTrigger_not_update() {
        useCase.validateName_ReturnValue = ValidationResult.invalid([TestError()])
        useCase.validatePrice_ReturnValue = ValidationResult.invalid([TestError()])
        
        // act
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.name("foo"))
        dataTrigger.onNext(DynamicEditProductViewModel.DataType.price("1.0"))
        updateTrigger.onNext(())
        let updateEnable = try? output.updateEnable.toBlocking(timeout: 1).first()
        
        // assert
        XCTAssertEqual(updateEnable, false)
        XCTAssertFalse(useCase.update_Called)
    }
    
    func test_updateTrigger_update() {
        // act
        updateTrigger.onNext(())
        
        // assert
        XCTAssert(useCase.update_Called)
    }
    
    func test_updateTrigger_update_fail_show_error() {
        // arrange
        let update_ReturnValue = PublishSubject<Void>()
        useCase.update_ReturnValue = update_ReturnValue.asObserver()
        
        // act
        updateTrigger.onNext(())
        update_ReturnValue.onError(TestError())
        let error = try? output.error.toBlocking(timeout: 1).first()
        
        // assert
        XCTAssert(useCase.update_Called)
        XCTAssert(error is TestError)
    }
    
}
