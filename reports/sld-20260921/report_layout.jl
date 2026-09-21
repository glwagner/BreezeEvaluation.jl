module ReportLayout
using CairoMakie
export textpages
function wraplines(text,width=87)
 out=String[];line=""
 for word in split(text)
  if length(line)+length(word)+1>width
   push!(out,line);line=String(word)
  else
   line=isempty(line) ? String(word) : line*" "*word
  end
 end
 isempty(line)||push!(out,line);out
end
function textpages(heading,paragraphs,prefix,work;footer="Breeze LES experiments | Julia report")
 mkpath(work);paths=String[];page=0;fig=nothing;ax=nothing;y=0.
 function newpage()
  page+=1
  fig=Figure(size=(850,1100),figure_padding=0)
  ax=Axis(fig[1,1],limits=(0,850,0,1100));hidedecorations!(ax);hidespines!(ax)
  text!(ax,44,1050,text=join(wraplines(heading,49),"\n"),fontsize=25,font=:bold,align=(:left,:top),color="#173e56")
  text!(ax,44,29,text=footer,fontsize=11,color="#607080")
  y=970.
 end
 function flushpage()
  path=joinpath(work,"$(prefix)_$(lpad(page,2,'0')).pdf");save(path,fig);push!(paths,path)
 end
 newpage()
 for paragraph in paragraphs
  lines=wraplines(replace(paragraph,r"\*\*"=>"",r"`"=>""))
  if 22length(lines)<=902 && y-22length(lines)<68
   flushpage();newpage()
  end
  for line in lines
   if y-22<68;flushpage();newpage();end
   text!(ax,44,y,text=line,fontsize=16,align=(:left,:top));y-=22
  end
  y-=16
 end
 flushpage();paths
end
end
