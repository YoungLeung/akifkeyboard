//
//  SpellcheckController.swift
//  keyboardExtension
//
//  Created by Akif Heren on 8/18/18.
//  Copyright © 2018 Akif Heren. All rights reserved.
//

import Foundation

class SpellCheckModel{
    
    let isCorrect: Bool
    let alternatives: [String]
//    let middle: String
//    let left: String
//    let right: String
    
    init(isCorrect: Bool, alternatives: [Word]) {
        self.isCorrect = isCorrect
        // Ensure the best prediction is on the most right.
        let setOfAlternatives = Array(Set(Array(alternatives.prefix(4))).sorted(by: { $0.weight < $1.weight }).map{value in value.word});
        self.alternatives = setOfAlternatives
    }
}

class SpellCheckController{
    var autoComplete = AutoComplete<Word>()
    var correctSpelling = CorrectSpelling()
    
    let endpoint: String = "https://2hwrmsajo2.execute-api.eu-central-1.amazonaws.com/Prod/spellcheck?prompt="

    var filename = ""
    var autocompleteCutoffFrequency = 3;
    
    init(filename: String, autocompleteCutoffFrequency: Int) {
        self.filename = filename;
        self.autocompleteCutoffFrequency = autocompleteCutoffFrequency;
        
        DispatchQueue.global(qos: .background).async {
            self.loadData()
        }
    }
    
    func loadData(){
        do {
            let path = Bundle.main.path(forResource: self.filename, ofType: "csv")
            
//            if let streamReader = StreamReader(path: path!) {
//                while let line = streamReader.nextLine() {
//                    let lineItems  = line.components(separatedBy: ",")
//                    if(lineItems.count == 2){
//                        let frequency = Int(lineItems[1]) ?? 1;
//                        let word = String(lineItems[0]);
//
//                        if(frequency > self.autocompleteCutoffFrequency){
//                            self.autoComplete.insert(Word(word: word, weight: frequency))
//                        }
//
//                        self.correctSpelling.insertWord(word: Word(word: word, weight: frequency))
//                    }
//                }
//            }
            
            let data = try String(contentsOfFile: (path)!, encoding: .utf8)
            data.components(separatedBy: .newlines).forEach({
                let lineItems  = $0.split(separator: ",")
                if(lineItems.count == 2){
                    let frequency = Int(lineItems[1]) ?? 1;
                    let word = String(lineItems[0]);

                    if(frequency > self.autocompleteCutoffFrequency){
                        self.autoComplete.insert(Word(word: word, weight: frequency))
                    }
                    self.correctSpelling.insertWord(word: Word(word: word, weight: frequency))
                }
            })
        } catch {
            print(error)
        }
    }
    
    func checkSpelling(currentWord: String, completion: @escaping (_ result: SpellCheckModel)->()){
        DispatchQueue.global(qos: .background).async {
        
            let results = self.autoComplete.search(currentWord)
        
            let keyDist1 = self.getAlternatives(word: currentWord)
            let keyDist1Results = keyDist1.flatMap {self.autoComplete.search($0)}.map{Word(word: $0.word, weight: Int(Double($0.weight) / 4.0))}
            
            var corrections: [Word] = [];
            if results.count < 4{
                corrections = self.correctSpelling.getCorrection(word: currentWord.lowercased());
            }

            let alternatives = results
                + keyDist1Results
                + corrections

            DispatchQueue.main.async {
                completion(SpellCheckModel(isCorrect: false,
                   alternatives: alternatives.sorted(by: { $0.weight > $1.weight })))
            }
        }
    }
    
    func getURI(url: String, completion: @escaping (_ result: SpellCheckModel)->()){
        let url = URL(string: url) ?? nil
        
        if(url == nil){ return }
        
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        //request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            if(response == nil){
                return;
            }
            
            print(response!)
            do {
                let json = try JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                print(json["isCorrect"])
                print(json["suggested"])
                
                //completion(SpellCheckModel(isCorrect: (json["isCorrect"] != nil), alternatives: json["suggested"] as! [String]))
                
            } catch {
                print("error")
            }
        })
        
        task.resume()
    }
    
    func getAlternatives(word: String) -> [String]{
        var characterMapping = ["a" : "s",
                                "b" : "vn",
                                "c" : "xv",
                                "d" : "sf",
                                "e" : "wr",
                                "f" : "dg",
                                "g" : "fh",
                                "h" : "gj",
                                "i" : "uo",
                                "j" : "hk",
                                "k" : "jl",
                                "l" : "k",
                                "m" : "n",
                                "n" : "bm",
                                "o" : "ip",
                                "p" : "o",
                                "q" : "w",
                                "r" : "et",
                                "s" : "ad",
                                "t" : "ry",
                                "u" : "yi",
                                "v" : "cb",
                                "w" : "qe",
                                "x" : "zc",
                                "y" : "tu",
                                "z" : "x"];
        
        let splits = word.indices.map {
            (word[word.startIndex..<$0], word[$0..<word.endIndex])
            } as [(Substring, Substring)]
        
        func abc(left: Substring, right: Substring) -> [String]{
            let char = String(right.first!).lowercased()
            var exists = characterMapping[char] != nil
            if exists == false{
                return [];
            }
            
            let alphabet : String = String(characterMapping[char]!)
            return alphabet == nil ? [] : alphabet.map { "\(left)\($0)\(right.dropFirst())" }
        }
        
        let replaces = splits.flatMap { left, right in
            abc(left: left, right: right)
        } as [String]
        
        return Array(Set(replaces));
    }
}

