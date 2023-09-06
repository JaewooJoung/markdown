using HTTP,DataFrames,Dates,XML,EzXML,Weave,SQLite,CSV
using Downloads: download

function weaving(OutFolder,File,OutSelect)
    filename = File
    doct = ["pandoc","md2html","md2tex","pandoc2pdf","md2pdf"] 
    docTo = doct[OutSelect]
    #println("weave($filename; doctype = $docTo, out_path = $OutFolder)")
    weave(filename; doctype = docTo, out_path = OutFolder)
end

function FileLog(Filename::String,logme::String) #not using traditional logging because this is not log
    logme =logme *"\r\n" #add return 
    io =  open(Filename, "w"; lock = true) # "a+" is append this will add to the file  
    write(io,logme) #add log 
    close(io);lock = false #must close for efficiency
end

function chinese(year::Int)
    pinyin = Dict("甲" => "갑","乙" => "을","丙" => "병","丁" => "정","戊" => "무","己" => "기","庚" => "경","辛" => "신","壬" => "임","癸" => "계","子" => "자","丑" => "축","寅" => "인","卯" => "묘","辰" => "진","巳" => "사","午" => "오","未" => "미","申" => "신","酉" => "유","戌" => "술","亥" => "해")
    elements    = ["목(청색)", "화(적색)", "토(황색)", "금(백색)", "수(흑색)"]
    animals     = ["쥐(🐭)", "소(🐂)", "범(🐯)", "토끼(🐇)", "드래곤(🐉)", "뱀(🐍)", "말(🐴)", "양(🐏)", "원숭이(🐵)", "닭(🐔)", "개(🐶)", "돼지(🐷)"]
    celestial   = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    terrestrial = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    aspects     = ["양(+)", "음(-)"]
    base = 4

    cycleyear = year - base

    stemnumber = cycleyear % 10 + 1
    stemhan    = celestial[stemnumber]
    stempinyin = pinyin[stemhan]

    elementnumber = div(stemnumber, 2) + 1
    element       = elements[elementnumber]

    branchnumber = cycleyear % 12 + 1
    branchhan    = terrestrial[branchnumber]
    branchpinyin = pinyin[branchhan]
    animal       = animals[branchnumber]

    aspectnumber = cycleyear % 2 + 1
    aspect       = aspects[aspectnumber]

    index = cycleyear % 60 + 1

    return "$year 년 [$stemhan$branchhan] 年 ($stempinyin$branchpinyin 년, $element $animal; $aspect 의 해 의며 육십갑자의 $index 번째 해)"
end

function getmynews(htp,upcut,downcut)
    r = HTTP.request("GET", htp; retries=2, cookies=true)
    X = String(r.body)
    X = split(X,upcut)
    Y = split(X[2],downcut)
    return Y[1]
end

function Leftnews()
    MyString = []

    htp  = "https://www.hani.co.kr/rss/"
    r = HTTP.request("GET", htp; retries=2, cookies=true)
    doc = parsexml(String(r.body))
    channel = root(doc) 
    cnt = 0
    for item in eachelement(channel)
        for title in eachelement(item)
            cnt +=1
            title_name = nodecontent(title)  # or `species.content`
            if (cnt == 6 )
                push!(MyString,"최근 뉴스: 한국시간 (",title_name, ")","\n")
            elseif (cnt > 6 )
                title_name = replace(title_name,"nowrap></td></tr></table>"=>"\n\t\t\t\t")
                mtitle = split(title_name,"\n\t\t\t\t")
                popat!(mtitle,4)
                popfirst!(mtitle)
                (length(mtitle) <= 4) ? continue :
                clearstr = (length(mtitle)==5) ? string(mtitle[5], "➖","\t[",mtitle[1],"]","(",mtitle[2],")","\n 📖[ ",mtitle[3], "💬@",mtitle[4],"\n") : string(mtitle[6],"➖","\t[",mtitle[1],"]","(",mtitle[2],")","\n##### \t📍",mtitle[5],"\n###### 📖 ",mtitle[3], "💬@",mtitle[4],"\n") 
                clearstr = replace(clearstr, r"<.+?>"=> "", r"&.+?;"=> "","\n\t\t"=>"")
                #clearstr = replace(clearstr,"<br />"=>" ","&amp;lt;"=>" ","&amp;gt;"=>" ","</span>"=>" ","""<span style="color: #c21a1a;">"""=>" ","<span>"=>" ","\n\t\t"=>"")
                clearstr = replace(clearstr,"경제➖"=>"경제(📊)➖","사회➖"=>"사회(🌈)➖","정치➖"=>"정치(🎴)➖","국제➖"=>"국제(🌐)➖","전국➖"=>"전국(🌏)➖","문화➖"=>"문화(🎬)➖","스포츠➖"=>"스포츠(🏄)➖","English Edition➖"=>"Eng.(🔠)➖","애니멀피플➖"=>"반려동물(🐳)➖")
                #clearstr = replace(clearstr,"""<span style="color:"""=>" ",""";">"""=>" ")
                push!(MyString,string("\n#### \t 📌",clearstr))
            end
        end
    end
    return join(MyString)
end

function DevHTML()
    지금 = Date(today())
    현재 = Time(now())
    Now = string(Dates.now())
    clearstr = replace(Now,"-"=>"`",":"=>"`","T"=>"`","."=>"`")
    T1 = split(clearstr,"`")
    Myday =  string(T1[1],T1[2],T1[3],T1[4],T1[5],T1[6])

    Mstr ="""
    \n
    ## (づ￣ 3￣)づ \t재외동포(在外同胞) 정보지(信息刊物) \t✍(◔◡◔)😘
    ----------------------------
    """
    ML = "$Myday.jmd"
    Mstr *= string("#### ", chinese(Dates.year(지금)))
    Mstr *= string("\n##### 중국시간 으로 :",(Dates.month(지금)),"월 ",(Dates.day(지금)),"일,  ", Dates.hour(현재),"시", Dates.minute(현재),"분에 재외동포분들이 보기쉽게 자동으로 긁어모음\n")

    Mstr *= Leftnews()
    Mstr *= """

    ----------------------------
    ###     주요 이슈들
    ----------------------------
    """
    htp  = "https://quicknews.co.kr/"
    upcut = "간추린 아침뉴스입니다."
    downcut = "출처간추린 아침뉴스"
    Mstr *= replace(getmynews(htp,upcut,downcut),"● "=>"* ")

    upcut = "주요경제지표"
    downcut = "매일 아침 간추린뉴스"
    Mstr *= """----------------------------
    ###      경제지표
    """
    Mstr *= replace(getmynews(htp,upcut,downcut),"● "=>"* ","52주"=>"\t+ 52주","     "=>"###     ")

    Mstr *= """----------------------------
    ###      환율표
    ----------------------------
    """

    htp  = "https://search.naver.com/search.naver?query=%ED%99%98%EC%9C%A8&ie=utf8&sm=whl_nht"
    upcut = "</caption>"
    downcut = "</tr> </tbody> </table> </div> </div>"
    B = replace(getmynews(htp,upcut,downcut),"""<span class="ico">"""=>"<span>")
    Z = split(B,"<span>")
    C = []
    for i in 1:length(Z)
        A = split(Z[i],"<")
        push!(C,A[1])
    end 
    for i in 1:5
    popfirst!(C)
    end
    str = string("|국가|환율|전일대비|퍼센트|\n")
    str *= string("|:--:|:--:|:--:|:--:|\n")

    for i in 1:4:(length(C))
        Tc = (parse(Float64, replace(strip(C[i+1], [' ', ',', '\n']),","=>"")))  
        str *= string("|$(C[i])|$(Tc)|$(C[i+2])|$(C[i+3])|\n")
    end

    Mstr *= str

    initial  = """
    \n---
    ##### E-mail📧: [jaewoo.joung@outlook.com](mailto:jaewoo.joung@outlook.com)
    ##### Mobile📱:+86-130-6582-6195
    """

    Mstr *= initial

    FileLog(ML,Mstr)
    Tfolder = "..\\markdown\\"
    #Tfolder = "C:\\Users\\jaewo\\Documents\\myproj\\markdown\\"
    # OtSlc = 4 #1:"markdown",2:"md2html",3:"md2tex",4:"pandoc2pdf",5:"md2pdf"] 
    for OtSlc in 1:2
        (OtSlc == 3) ? nothing : weaving(Tfolder,ML,OtSlc)
    end
    
    #push!(RtnVal,jmdname)
    return T1
end
function SQLIntfce(T1)
    Myday =  string(T1[1],T1[2],T1[3],T1[4],T1[5],T1[6])
    dbname = "D:\\project\\NewsFeed.db" #static
    myresult = "D:\\project\\NewsQL.csv"
    db = SQLite.DB(dbname)
    crtdb = (db,tbname,tbschma) -> SQLite.execute(db, "CREATE TABLE IF NOT EXISTS $tbname($tbschma)")
    sqlinsrt = (db,tbname,tbvalue) -> SQLite.execute(db, "INSERT INTO $tbname VALUES($tbvalue)") 
    exec = (db,mystr) -> DBInterface.execute(db, mystr) #execdb(db) to excute quick
    
    tbschma = "HTML REAL"
    tbname = "TDate"
    crtdb(db,tbname,tbschma)
    println("created")
    tbname = "TDate";tbschma = "'$Myday.html'"
    sqlinsrt(db,tbname,tbschma)
    println("inserted")
    
    myStr = "SELECT * FROM $tbname ORDER BY HTML DESC"
    r = exec(db, myStr) #DBInterface.execute(db, myStr)
    CSV.write(myresult, r)# should be getting it with dataframe 
    df = CSV.read(myresult,DataFrame)
    println(df)
    return T1,df
end

TX,dfX= SQLIntfce(DevHTML())

println(TX,"\n",dfX)