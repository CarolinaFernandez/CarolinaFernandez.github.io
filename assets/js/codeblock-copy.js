// Adapted from https://www.aleksandrhovhannisyan.com/blog/how-to-add-a-copy-to-clipboard-button-to-your-jekyll-blog/

const codeBlocks = document.querySelectorAll(".code-header + .highlighter-rouge");
const copyCodeButtons = document.querySelectorAll(".copy-code-button");

copyCodeButtons.forEach((copyCodeButton, index) => {
    //const code = codeBlocks[index].innerText;
    var code = "";

    copyCodeButton.addEventListener("click", () => {
        // In this case, code must be taken from inner rouge DOM elements,
	// specifically the second cell in each row (since row[0] is used to
	// keep the numbering for each line
        const codeTable = codeBlocks[index].getElementsByClassName("highlight")[0].getElementsByClassName("highlight")[0].getElementsByClassName("rouge-table")[0];
        for (var i = 0, row; row = codeTable.rows[i]; i++) {
            code += row.cells[1].innerText;
        }
    
        window.navigator.clipboard.writeText(code);
        copyCodeButton.classList.add("copied");

        setTimeout(() => {
            copyCodeButton.classList.remove("copied");
        }, 2000);
    });
});
