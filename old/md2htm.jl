using Weave

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


weaving("/media/crux/a48b9489-1886-47de-bfd7-0c9bef45a8f9/markdown/old/","/media/crux/a48b9489-1886-47de-bfd7-0c9bef45a8f9/markdown/old/20240528jaewoojoungcv.jmd",5)

