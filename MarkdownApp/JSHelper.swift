//
//  JSHelper.swift
//  MarkdownApp
//
//  Created by 刘小龙 on 2026-04-29.
//

import Foundation

enum JSHelper {
   
    struct Code {
        static let css = """
            /* === code block copy button === */
            .code-block {
                position: relative;
            }

            .copy-btn {
                position: absolute;
                top: 6px;
                right: 6px;
                padding: 4px 8px;
                font-size: 12px;
                cursor: pointer;
                border: none;
                background: rgba(0,0,0,0.6);
                color: #fff;
                border-radius: 4px;
                opacity: 0;
                transition: opacity 0.2s;
            }

            .code-block:hover .copy-btn {
                opacity: 1;
            }

            .copy-btn.copied {
                background: #4caf50;
            }
            """
        static let js = """
            // === add copy button to code blocks ===
            function enhanceCodeBlocks() {
                document.querySelectorAll('pre code').forEach(block => {
                    const pre = block.parentNode;

                    // 避免重复包裹
                    if (pre.parentNode.classList.contains('code-block')) return;

                    const wrapper = document.createElement('div');
                    wrapper.className = 'code-block';

                    const button = document.createElement('button');
                    button.className = 'copy-btn';
                    button.innerText = 'Copy';

                    pre.parentNode.insertBefore(wrapper, pre);
                    wrapper.appendChild(button);
                    wrapper.appendChild(pre);

                    button.addEventListener('click', () => {
                        const text = block.innerText;

                        if (navigator.clipboard) {
                            navigator.clipboard.writeText(text);
                        } else {
                            const textarea = document.createElement('textarea');
                            textarea.value = text;
                            document.body.appendChild(textarea);
                            textarea.select();
                            document.execCommand('copy');
                            document.body.removeChild(textarea);
                        }

                        button.innerText = 'Copied!';
                        button.classList.add('copied');

                        setTimeout(() => {
                            button.innerText = 'Copy';
                            button.classList.remove('copied');
                        }, 1500);
                    });
                });
            }
            """
    }
    
    
}
